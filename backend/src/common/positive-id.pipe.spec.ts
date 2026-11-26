import { BadRequestException } from '@nestjs/common';
import { PositiveIdPipe } from './positive-id.pipe';

describe('PositiveIdPipe', () => {
  const pipe = new PositiveIdPipe();

  it('acepta solo enteros positivos seguros', () => {
    expect(pipe.transform('42')).toBe(42);
    for (const invalid of ['abc', '0', '-1', '1.5', '1e3', '9007199254740992']) {
      expect(() => pipe.transform(invalid)).toThrow(BadRequestException);
    }
  });
});
