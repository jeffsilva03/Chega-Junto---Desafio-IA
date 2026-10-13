// Pacote estático com allowlist; não copia docs, testes ou configurações privadas.
import {cp, mkdir, readdir, rm, stat} from 'node:fs/promises';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const target=resolve(root,'dist');
if (dirname(target)!==root || target===root) throw new Error('Destino de build inválido.');
await rm(target,{recursive:true,force:true});
await mkdir(target,{recursive:true});
for (const name of ['index.html','css','js','assets']) await cp(join(root,name),join(target,name),{recursive:true});
async function verify(path) {
  for (const name of await readdir(path)) {
    const entry=join(path,name);
    if ((await stat(entry)).isDirectory()) await verify(entry);
    else if (!/\.(html|css|js|svg|ttf|txt)$/.test(name) || name.startsWith('.')) throw new Error('Arquivo inesperado no pacote público.');
  }
}
await verify(target);
console.log('Portal empacotado em dist: index.html, css, js e assets.');
