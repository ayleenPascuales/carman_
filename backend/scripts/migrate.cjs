const { createHash } = require('node:crypto');
const { readdirSync, readFileSync } = require('node:fs');
const { join } = require('node:path');
const { createConnection } = require('mysql2/promise');
const { databaseOptions } = require('../dist/database/database.config.js');

async function main() {
  for (const key of ['DB_HOST', 'DB_USER', 'DB_PASSWORD', 'DB_NAME']) {
    if (!process.env[key]) throw new Error(`Falta ${key}`);
  }
  const { host, port, user, password, database, ssl, connectTimeout } =
    databaseOptions(process.env);
  const db = await createConnection({ host, port, user, password, database, ssl, connectTimeout });
  try {
    const [tables] = await db.query(
      `SELECT TABLE_NAME AS name FROM information_schema.tables
       WHERE TABLE_SCHEMA = DATABASE()`,
    );
    const hasHistory = tables.some((table) => table.name === 'schema_migrations');
    if (!hasHistory && tables.length > 0) {
      throw new Error('Ya existen tablas sin migraciones registradas. Revisa el esquema antes de migrar.');
    }
    const [applied] = hasHistory
      ? await db.query('SELECT name, checksum FROM schema_migrations')
      : [[]];
    if (!applied.length && tables.some((table) => table.name !== 'schema_migrations')) {
      throw new Error('Ya existen tablas sin migraciones registradas. Revisa el esquema antes de migrar.');
    }
    if (!hasHistory) {
      await db.query(`CREATE TABLE schema_migrations (
        name VARCHAR(255) NOT NULL PRIMARY KEY,
        checksum CHAR(64) NOT NULL,
        applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
      )`);
    }
    const versions = new Map(applied.map((row) => [row.name, row.checksum]));
    const directory = join(__dirname, '..', 'migrations');
    for (const name of readdirSync(directory).filter((file) => /^\d+_.*\.sql$/.test(file)).sort()) {
      const sql = readFileSync(join(directory, name), 'utf8');
      const checksum = createHash('sha256').update(sql).digest('hex');
      if (versions.has(name)) {
        if (versions.get(name) !== checksum) {
          throw new Error(`La migración ${name} fue modificada después de aplicarse`);
        }
        continue;
      }
      // TiDB confirma DDL de forma no transaccional; inspecciona el esquema si falla.
      for (const statement of sql.split(/;\s*(?:\r?\n|$)/).map((part) => part.trim()).filter(Boolean)) {
        await db.query(statement);
      }
      await db.execute('INSERT INTO schema_migrations (name, checksum) VALUES (?, ?)', [name, checksum]);
      console.log(`Migración aplicada: ${name}`);
    }
  } finally {
    await db.end();
  }
}

main().catch((error) => {
  console.error('No se pudo aplicar el esquema:', error);
  process.exitCode = 1;
});
