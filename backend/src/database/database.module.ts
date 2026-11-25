<<<<<<< HEAD
import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createPool } from 'mysql2/promise';
import { readFileSync } from 'fs';
import { join } from 'path';

=======
import { Inject, Injectable, Module, OnApplicationShutdown } from '@nestjs/common';
import { createPool, type Pool } from 'mysql2/promise';
import { databaseOptions } from './database.config';

@Injectable()
class DatabaseLifecycle implements OnApplicationShutdown {
  constructor(@Inject('DATABASE_CONNECTION') private readonly database: Pool) {}

  async onApplicationShutdown() {
    await this.database.end();
  }
}
>>>>>>> ae87ce29ae5976844860442f2463c9a85d16c754

@Module({
    providers: [
        {
            provide: 'DATABASE_CONNECTION',
            useFactory: async () => {
                const pool = createPool(databaseOptions(process.env));
                try {
                    await pool.query('SELECT 1');
                } catch (error) {
                    await pool.end();
                    throw error;
                }
                return pool;
            },
        },
        DatabaseLifecycle,
    ],
    exports: ['DATABASE_CONNECTION'],
})
export class DatabaseModule { }
