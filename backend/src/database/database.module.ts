import { Inject, Injectable, Module, OnApplicationShutdown } from '@nestjs/common';
import { createPool, type Pool } from 'mysql2/promise';
import { databaseOptions } from './database.config';

@Injectable()
class DatabaseLifecycle implements OnApplicationShutdown {
    constructor(@Inject('DATABASE_CONNECTION') private readonly database: Pool) { }

    async onApplicationShutdown() {
        await this.database.end();
    }
}

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
