'use strict';
const { migrate, close, hostVisible } = require('../config/database');

migrate()
  .then(() => console.log(`✔ Migración completada en ${hostVisible()}`))
  .catch((err) => {
    console.error('✘ Migración fallida:', err.message);
    process.exitCode = 1;
  })
  .finally(close);
