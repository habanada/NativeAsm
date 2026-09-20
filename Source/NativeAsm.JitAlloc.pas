{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.JitAlloc;

{
  NativeAsm — Pooled JIT Memory Allocator
  ===============================================
  Author : Selahattin Erkoc
  Inspired by AsmJit's JitAllocator design.

  Design overview
  ---------------
  Rather than calling VirtualAlloc for every generated stub (expensive:
  each call maps a minimum of one 4 KB page and a new VAD entry), this
  allocator pre-allocates large chunks (default 64 KB, one OS page-group)
  and sub-allocates from them with a bump pointer.

  W^X policy
  ----------
  Chunks are allocated PAGE_READWRITE so generated code can be written
  with ordinary pointer stores.  When a region is fully emitted, the
  caller calls Commit(Ptr, Size): this calls VirtualProtect on the
  exact page range and FlushInstructionCache, making the code executable.

  Lifetime
  --------
  All chunks are owned by the allocator; calling Free/Reset releases them.
  Individual sub-allocations cannot be freed selectively — this matches
  how JIT compilers work (emit once, keep forever until GC sweep).

  Public surface
  --------------
    Alloc(Size)         – bump-allocate Size RW bytes from current chunk
                          (grows by one new chunk if needed)
    Commit(Ptr, Size)   – flip range to PAGE_EXECUTE_READ
    Reset               – release all chunks, reset to empty state
    TotalAllocated      – total bytes reserved across all chunks
    TotalUsed           – total bytes handed out via Alloc
    ChunkSize           – the chunk granularity (read-only)
}

{$ALIGN ON}
{$MINENUMSIZE 4}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$WEAKLINKRTTI ON}

interface

uses
  Winapi.Windows,
  System.SysUtils;

const
  /// <summary>Default chunk size: 64 KB — one OS large-page region.</summary>
  DefaultJitChunkSize = 65536;

type
  EJitAllocError = class(Exception);

  /// <summary>
  ///   Pooled, W^X JIT memory allocator.
  ///   Allocate a block with Alloc(), write code into it, then call Commit()
  ///   to flip it to PAGE_EXECUTE_READ and flush the instruction cache.
  /// </summary>
  TJitAllocator = class
  private
    type
      /// <summary>One OS-level allocation (VirtualAlloc region).</summary>
      TChunk = record
        Base       : Pointer;  // start of the VirtualAlloc region
        Total      : Integer;  // total bytes allocated for this chunk
        Used       : Integer;  // bytes already handed out to callers
        IsCommitted: Boolean;  // True once Commit() has been called for this chunk
        // W^X note: VirtualProtect is page-granular, so committing any byte in
        // a page flips the entire page to RX.  To prevent write-faults when a
        // new sub-allocation lands in the same page, we treat the whole chunk as
        // committed and always start a fresh chunk after the first Commit call.
      end;

  private
    FChunks   : array of TChunk;
    FCount    : Integer;   // number of live chunks
    FChunkSize: Integer;   // size of each new chunk
    FTotalUsed: Integer;   // running sum of bytes handed out

    /// <summary>Allocate a new chunk and append it to FChunks.</summary>
    procedure AddChunk;

  public
    /// <summary>
    ///   Create an allocator.
    ///   ChunkSize must be a multiple of the system page size (4096).
    ///   Values below 4096 are raised to 4096; values not page-aligned are
    ///   rounded up to the next multiple of 4096.
    /// </summary>
    constructor Create(ChunkSize: Integer = DefaultJitChunkSize);
    destructor  Destroy; override;

    // ── Allocation ────────────────────────────────────────────────────────────

    /// <summary>
    ///   Bump-allocate Size bytes from the current chunk, aligned to 16 bytes.
    ///   Returns a pointer to PAGE_READWRITE memory ready for code writing.
    ///   If the current chunk has insufficient space, a new chunk is created.
    ///   Raises EJitAllocError if Size exceeds ChunkSize.
    /// </summary>
    function Alloc(Size: Integer): Pointer;

    // ── Commit ────────────────────────────────────────────────────────────────

    /// <summary>
    ///   Flip Ptr..Ptr+Size-1 to PAGE_EXECUTE_READ and flush the instruction
    ///   cache for the affected range.  Ptr must point inside a previously
    ///   Alloc'd block.  The underlying VirtualProtect is page-granular:
    ///   committing any byte in a 4 KB page makes the entire page executable;
    ///   the chunk containing Ptr is therefore marked IsCommitted so that
    ///   subsequent Alloc() calls start a new chunk rather than writing into
    ///   already-committed (RX, non-writable) pages.
    /// </summary>
    procedure Commit(Ptr: Pointer; Size: Integer);

    /// <summary>
    ///   Commit all chunks that have been written to but not yet committed.
    ///   Call this after emitting a batch of stubs to make them all executable
    ///   in a single pass rather than committing each one individually.
    /// </summary>
    procedure CommitAll;

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    /// <summary>Release all chunks and reset to the initial empty state.</summary>
    procedure Reset;

    // ── Diagnostics ──────────────────────────────────────────────────────────

    /// <summary>Total bytes reserved from the OS (sum of all chunk sizes).</summary>
    function TotalAllocated: Integer;

    /// <summary>Total bytes handed to callers via Alloc (alignment pads included).</summary>
    function TotalUsed: Integer;

    /// <summary>Number of OS chunks currently held.</summary>
    function ChunkCount: Integer; inline;

    property ChunkSize: Integer read FChunkSize;
  end;

implementation

// ── Constants ─────────────────────────────────────────────────────────────────

const
  PageSize       = 4096;
  AllocAlignment = 16;   // sub-allocations aligned to 16 bytes

// ── Helpers ───────────────────────────────────────────────────────────────────

function AlignUp(V, Align: Integer): Integer; inline;
begin
  Result := (V + Align - 1) and (not (Align - 1));
end;

// ── TJitAllocator ─────────────────────────────────────────────────────────────

constructor TJitAllocator.Create(ChunkSize: Integer);
begin
  if ChunkSize < PageSize then
    ChunkSize := PageSize;
  // Round up to page boundary
  ChunkSize := AlignUp(ChunkSize, PageSize);

  FChunkSize := ChunkSize;
  FCount     := 0;
  FTotalUsed := 0;
  SetLength(FChunks, 0);
end;

destructor TJitAllocator.Destroy;
begin
  Reset;
  inherited;
end;

procedure TJitAllocator.AddChunk;
var
  Ptr: Pointer;
begin
  Ptr := VirtualAlloc(nil, FChunkSize, MEM_COMMIT or MEM_RESERVE, PAGE_READWRITE);
  if Ptr = nil then
    RaiseLastOSError;

  if FCount >= Length(FChunks) then
    SetLength(FChunks, FCount + 8);

  FChunks[FCount].Base        := Ptr;
  FChunks[FCount].Total       := FChunkSize;
  FChunks[FCount].Used        := 0;
  FChunks[FCount].IsCommitted := False;
  Inc(FCount);
end;

function TJitAllocator.Alloc(Size: Integer): Pointer;
var
  Aligned: Integer;
  Chunk  : ^TChunk;
begin
  if Size <= 0 then
    raise EJitAllocError.Create('TJitAllocator.Alloc: size must be positive');

  Aligned := AlignUp(Size, AllocAlignment);

  if Aligned > FChunkSize then
    raise EJitAllocError.CreateFmt(
      'TJitAllocator.Alloc: requested %d bytes exceeds chunk size %d',
      [Size, FChunkSize]);

  // Ensure we have a chunk, it has enough space, AND it has not been
  // committed yet.  VirtualProtect is page-granular: a Commit call flips
  // the entire 4 KB page to RX, so any subsequent write into the same page
  // would cause an access violation.  We avoid this by refusing to sub-
  // allocate from a committed chunk.
  if (FCount = 0) or
     (FChunks[FCount - 1].Used + Aligned > FChunks[FCount - 1].Total) or
     FChunks[FCount - 1].IsCommitted then
    AddChunk;

  Chunk  := @FChunks[FCount - 1];
  Result := Pointer(NativeUInt(Chunk.Base) + NativeUInt(Chunk.Used));
  Inc(Chunk.Used, Aligned);
  Inc(FTotalUsed, Aligned);
end;

procedure TJitAllocator.Commit(Ptr: Pointer; Size: Integer);
var
  OldProtect: Cardinal;
  I         : Integer;
  ChunkIdx  : Integer;
  PtrAddr   : NativeUInt;
  PtrEnd    : NativeUInt;
  ChunkBase : NativeUInt;
  ChunkEnd  : NativeUInt;
begin
  if (Ptr = nil) or (Size <= 0) then Exit;

  // ── Step 1: validate ownership BEFORE touching any page protections ───────
  // AsmJit W^X principle: calling VirtualProtect on a pointer that does not
  // belong to us (or overflows a chunk boundary) is a policy violation that
  // may flip pages in an unrelated mapping.  Find and validate the owning
  // chunk first; only then is it safe to call VirtualProtect.
  ChunkIdx := -1;
  PtrAddr  := NativeUInt(Ptr);
  PtrEnd   := PtrAddr + NativeUInt(Size);

  for I := 0 to FCount - 1 do
  begin
    ChunkBase := NativeUInt(FChunks[I].Base);
    ChunkEnd  := ChunkBase + NativeUInt(FChunks[I].Total);

    if (PtrAddr >= ChunkBase) and (PtrAddr < ChunkEnd) then
    begin
      // ── Step 2: Ptr+Size must not overflow the chunk boundary ─────────────
      // VirtualProtect is page-granular; committing beyond Used bytes would
      // flip pages that were never handed to the caller.
      if PtrEnd > ChunkEnd then
        raise EJitAllocError.CreateFmt(
          'TJitAllocator.Commit: range Ptr..Ptr+Size-1 overflows chunk boundary ' +
          '(chunk ends at offset %d, but range ends %d bytes past it)',
          [FChunks[I].Total,
           Integer(PtrEnd - ChunkEnd)]);
      ChunkIdx := I;
      Break;
    end;
  end;

  if ChunkIdx = -1 then
    raise EJitAllocError.Create(
      'TJitAllocator.Commit: Ptr does not belong to any allocated chunk; ' +
      'only pointers returned by Alloc() may be committed');

  // ── Step 3: flip to PAGE_EXECUTE_READ now that all checks have passed ─────
  if not VirtualProtect(Ptr, Size, PAGE_EXECUTE_READ, OldProtect) then
    RaiseLastOSError;

  FlushInstructionCache(GetCurrentProcess, Ptr, Size);

  // Mark the owning chunk committed so Alloc() starts a fresh chunk rather
  // than handing out memory from already-RX pages (which would fault on write).
  FChunks[ChunkIdx].IsCommitted := True;
end;

procedure TJitAllocator.CommitAll;
var
  I         : Integer;
  OldProtect: Cardinal;
begin
  for I := 0 to FCount - 1 do
    if (FChunks[I].Used > 0) and not FChunks[I].IsCommitted then
    begin
      if not VirtualProtect(FChunks[I].Base, FChunks[I].Used,
               PAGE_EXECUTE_READ, OldProtect) then
        RaiseLastOSError;
      FlushInstructionCache(GetCurrentProcess,
        FChunks[I].Base, FChunks[I].Used);
      FChunks[I].IsCommitted := True;
    end;
end;

procedure TJitAllocator.Reset;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    if FChunks[I].Base <> nil then
    begin
      VirtualFree(FChunks[I].Base, 0, MEM_RELEASE);
      FChunks[I].Base := nil;
    end;

  FCount     := 0;
  FTotalUsed := 0;
  SetLength(FChunks, 0);
end;

function TJitAllocator.TotalAllocated: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FCount - 1 do
    Inc(Result, FChunks[I].Total);
end;

function TJitAllocator.TotalUsed: Integer;
begin
  Result := FTotalUsed;
end;

function TJitAllocator.ChunkCount: Integer;
begin
  Result := FCount;
end;

end.
