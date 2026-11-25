import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createPool } from 'mysql2/promise';
import { readFileSync } from 'fs';
import { join } from 'path';


@Module({
    providers: [
        {
            provide: 'DATABASE_CONNECTION',
            inject: [ConfigService],
            useFactory: async (configService: ConfigService) => {
                const ca = readFileSync(join(process.cwd(), 'certs', 'isrgrootx1.pem'));

                const pool = createPool({
                    host: configService.get<string>('DB_HOST'),
                    port: Number(configService.get<string>('DB_PORT')),
                    user: configService.get<string>('DB_USER'),
                    password: configService.get<string>('DB_PASSWORD'),
                    database: configService.get<string>('DB_NAME'),
                    ssl: { ca, },
                    waitForConnections: true,
                    connectionLimit: 10,
                    queueLimit: 0,
                });
                const connection = await pool.getConnection();
                try {
                    await connection.query('SELECT 1');
                    console.log('Conexion con TiDB establecida correctamente');
                } finally {
                    connection.release();
                }
                return pool;
            },
        },
    ],
    exports: ['DATABASE_CONNECTION'],
})
export class DatabaseModule { }