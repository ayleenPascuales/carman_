import { SetMetadata } from '@nestjs/common';

export const ALLOW_UNVERIFIED = 'allowUnverified';
export const AllowUnverified = () => SetMetadata(ALLOW_UNVERIFIED, true);
