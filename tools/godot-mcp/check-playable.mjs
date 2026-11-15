import { Client } from './server/node_modules/@modelcontextprotocol/sdk/dist/client/index.js';
import { StdioClientTransport } from './server/node_modules/@modelcontextprotocol/sdk/dist/client/stdio.js';
import { fileURLToPath } from 'node:url';
import { readFileSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const projectPath = fileURLToPath(new URL('../../', import.meta.url));
const config = readFileSync(join(projectPath, '.codex/config.toml'), 'utf8');
const godotPath = process.env.GODOT_PATH || config.match(/^GODOT_PATH\s*=\s*'([^']+)'/m)?.[1];
if (!godotPath) throw new Error('Missing GODOT_PATH');
// Each invocation gets its own save directory; never overwrite a player's autosave.
const testRoot = join(projectPath, '.test_playable', `mcp-${Date.now()}`);
mkdirSync(testRoot, { recursive: true });
const scene = process.argv[2] || 'res://tests/integration/run_playable_flow.tscn';
const resultFile = process.argv[3] || 'playable-result.json';
if (!/^[a-z-]+\.json$/.test(resultFile)) throw new Error('Invalid result filename');
const resultPath = join(testRoot, 'Godot/app_userdata/BEYOND OUR HOME', resultFile);
const client = new Client({ name: 'playable-integration-check', version: '1.0.0' }, { capabilities: {} });
const transport = new StdioClientTransport({
  command: process.execPath,
  args: [join(projectPath, 'tools/godot-mcp/server/build/index.js')],
  env: { ...process.env, GODOT_PATH: godotPath, APPDATA: testRoot },
});
try {
  await client.connect(transport);
  const run = await client.callTool({ name: 'run_project', arguments: { projectPath, scene } });
  if (run.isError) throw new Error(JSON.stringify(run));
  let debug;
  for (let poll = 0; poll < 120; poll++) {
    await new Promise(resolve => setTimeout(resolve, 1000));
    debug = await client.callTool({ name: 'get_debug_output', arguments: {} });
    if (/SCRIPT ERROR|Debugger Break/.test(JSON.stringify(debug))) {
      writeFileSync(join(testRoot, 'mcp-debug.json'), JSON.stringify(debug, null, 2));
      // Stop only the test process created by this MCP connection on failure.
      await client.callTool({ name: 'stop_project', arguments: {} });
      throw new Error(`Script error during test; see ${join(testRoot, 'mcp-debug.json')}`);
    }
    if (existsSync(resultPath)) break;
    if (debug.isError) throw new Error(`Game exited before writing its result: ${JSON.stringify(debug)}`);
  }
  if (!existsSync(resultPath)) throw new Error('Timed out waiting for integration check');
  writeFileSync(join(testRoot, 'mcp-debug.json'), JSON.stringify(debug, null, 2));
  const result = JSON.parse(readFileSync(resultPath, 'utf8'));
  console.log(JSON.stringify({ passed: result.passed, failures: result.failures, captures: result.captures?.length, testRoot, debugSaved: join(testRoot, 'mcp-debug.json') }, null, 2));
  if (!result.passed || /SCRIPT ERROR/.test(JSON.stringify(debug))) process.exitCode = 1;
  // Let this test scene exit itself; do not stop any existing Godot session.
  await new Promise(resolve => setTimeout(resolve, 5000));
} finally {
  await client.close();
}
