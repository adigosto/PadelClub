const fs = require('node:fs');
const path = require('node:path');
const ts = require('C:/Users/User/AppData/Local/Programs/Microsoft VS Code/a44adf7f53/resources/app/extensions/node_modules/typescript/lib/typescript.js');
const root = path.resolve(__dirname, '../..');
const findings = JSON.parse(fs.readFileSync(path.join(__dirname, 'findings.json'), 'utf8'));
const canvasPath = 'C:/Users/User/.cursor/projects/c-Users-User-Desktop-PadelClub/canvases/RS2-security-review.canvas.tsx';
const canvas = fs.readFileSync(canvasPath, 'utf8');
const diagnostics = ts.transpileModule(canvas, {
  fileName: canvasPath,
  compilerOptions: { jsx: ts.JsxEmit.ReactJSX, target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ESNext },
  reportDiagnostics: true,
}).diagnostics || [];
const errors = diagnostics.filter(d => d.category === ts.DiagnosticCategory.Error);
for (const diagnostic of errors) console.error(ts.flattenDiagnosticMessageText(diagnostic.messageText, '\n'));
const brokenLocations = findings.flatMap(f => f.locations).filter(l => {
  const file = path.join(root, l.file);
  return !fs.existsSync(file) || fs.readFileSync(file, 'utf8').split(/\r?\n/).length < l.line;
});
const forbiddenCanvasPatterns = [/linear-gradient/, /radial-gradient/, /boxShadow/, /fetch\(/, /#[0-9a-f]{6}\b/i].filter(p => p.test(canvas)).map(String);
const probeBytes = fs.readFileSync(path.join(__dirname, 'probe-results.txt'));
const probes = JSON.parse(probeBytes.toString(probeBytes[0] === 255 && probeBytes[1] === 254 ? 'utf16le' : 'utf8').replace(/^\uFEFF/, ''));
const summary = JSON.stringify({ findings: findings.length, brokenLocations, canvasSyntaxErrors: errors.length, forbiddenCanvasPatterns, reproducedProbes: probes.filter(p => p.reproduced).length, limits: 'Syntax/transpile and source-link checks only; host rendering and full SDK type checking were not available.' }, null, 2);
fs.writeFileSync(path.join(__dirname, 'artifact-validation.txt'), summary + '\n', 'utf8');
console.log(summary);
process.exitCode = errors.length || brokenLocations.length || forbiddenCanvasPatterns.length ? 1 : 0;
