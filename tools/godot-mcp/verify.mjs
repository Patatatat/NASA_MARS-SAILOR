import { Client } from './server/node_modules/@modelcontextprotocol/sdk/dist/client/index.js';
import { StdioClientTransport } from './server/node_modules/@modelcontextprotocol/sdk/dist/client/stdio.js';
import { fileURLToPath } from 'node:url';
import { readFileSync } from 'node:fs';

const projectPath = fileURLToPath(new URL('../../', import.meta.url));
const config = readFileSync(new URL('../../.codex/config.toml', import.meta.url), 'utf8');
const godotPath = process.env.GODOT_PATH || config.match(/^GODOT_PATH\s*=\s*'([^']+)'/m)?.[1];
if (!godotPath) throw new Error('Set GODOT_PATH in the environment or .codex/config.toml');
const client = new Client({ name: 'godot-install-check', version: '1.0.0' }, { capabilities: {} });
const transport = new StdioClientTransport({
  command: process.execPath,
  args: [fileURLToPath(new URL('./server/build/index.js', import.meta.url))],
  env: { ...process.env, GODOT_PATH: godotPath },
});
try {
  await client.connect(transport);
  const { tools } = await client.listTools();
  console.log('Tools:', tools.map(t => t.name).join(', '));
  for (const name of ['get_godot_version', 'get_project_info']) {
    const result = await client.callTool({ name, arguments: name === 'get_project_info' ? { projectPath } : {} });
    if (result.isError) throw new Error(JSON.stringify(result));
    console.log(name, JSON.stringify(result));
  }
} finally {
  await client.close();
}
