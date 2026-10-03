function TAsmBmiHelper.Andn(A0: TOperand; A1: TOperand; A2: TOperand): TAsmBuilder;
begin
  Result := Bmi('andn', [A0, A1, A2]);
end;

function TAsmBmiHelper.Bextr(A0: TOperand; A1: TOperand; A2: TOperand): TAsmBuilder;
begin
  Result := Bmi('bextr', [A0, A1, A2]);
end;

function TAsmBmiHelper.Blsi(A0: TOperand; A1: TOperand): TAsmBuilder;
begin
  Result := Bmi('blsi', [A0, A1]);
end;

function TAsmBmiHelper.Blsmsk(A0: TOperand; A1: TOperand): TAsmBuilder;
begin
  Result := Bmi('blsmsk', [A0, A1]);
end;

function TAsmBmiHelper.Blsr(A0: TOperand; A1: TOperand): TAsmBuilder;
begin
  Result := Bmi('blsr', [A0, A1]);
end;

function TAsmBmiHelper.Bzhi(A0: TOperand; A1: TOperand; A2: TOperand): TAsmBuilder;
begin
  Result := Bmi('bzhi', [A0, A1, A2]);
end;

function TAsmBmiHelper.Mulx(A0: TOperand; A1: TOperand; A2: TOperand): TAsmBuilder;
begin
  Result := Bmi('mulx', [A0, A1, A2]);
end;

function TAsmBmiHelper.Pdep(A0: TOperand; A1: TOperand; A2: TOperand): TAsmBuilder;
begin
  Result := Bmi('pdep', [A0, A1, A2]);
end;

function TAsmBmiHelper.Pext(A0: TOperand; A1: TOperand; A2: TOperand): TAsmBuilder;
begin
  Result := Bmi('pext', [A0, A1, A2]);
end;

function TAsmBmiHelper.Rorx(A0: TOperand; A1: TOperand; A2: TOperand): TAsmBuilder;
begin
  Result := Bmi('rorx', [A0, A1, A2]);
end;

function TAsmBmiHelper.Sarx(A0: TOperand; A1: TOperand; A2: TOperand): TAsmBuilder;
begin
  Result := Bmi('sarx', [A0, A1, A2]);
end;

function TAsmBmiHelper.Shlx(A0: TOperand; A1: TOperand; A2: TOperand): TAsmBuilder;
begin
  Result := Bmi('shlx', [A0, A1, A2]);
end;

function TAsmBmiHelper.Shrx(A0: TOperand; A1: TOperand; A2: TOperand): TAsmBuilder;
begin
  Result := Bmi('shrx', [A0, A1, A2]);
end;

