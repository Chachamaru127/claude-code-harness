#!/usr/bin/env node
/**
 * Render Video Script
 *
 * Converts a video-script.json file to an MP4 video using Remotion.
 *
 * Usage:
 *   node scripts/render-video.js <video-script.json> [--output <path>]
 *
 * Example:
 *   node scripts/render-video.js out/video-script.json --output out/final-video.mp4
 *
 * Dependencies:
 *   - Remotion CLI (npx remotion render)
 *   - video-script.json (validated against schema)
 *
 * Process:
 *   1. Load and validate video-script.json
 *   2. Generate Remotion composition (or use existing)
 *   3. Resolve asset paths
 *   4. Calculate frame counts from durations
 *   5. Call Remotion CLI with appropriate settings
 *   6. Show progress and output final file path
 */

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const os = require('os');

// ANSI color codes for terminal output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  dim: '\x1b[2m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function logError(message) {
  log(`\u274c ${message}`, 'red');
}

function logSuccess(message) {
  log(`\u2705 ${message}`, 'green');
}

function logInfo(message) {
  log(`\u2139\ufe0f  ${message}`, 'cyan');
}

function logWarning(message) {
  log(`\u26a0\ufe0f  ${message}`, 'yellow');
}

/**
 * Parse command line arguments
 */
function parseArgs() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    console.log(`
${colors.bright}Render Video Script${colors.reset}

Usage:
  node scripts/render-video.js <video-script.json> [options]

Arguments:
  <video-script.json>    Path to video script file

Options:
  --output <path>        Output file path (default: out/video.mp4)
  --composition <name>   Remotion composition name (default: VideoComposition)
  --concurrency <num>    Rendering concurrency (default: 50% CPU cores)
  --quality <level>      Quality: low|medium|high|ultra (default: from script)
  --preview              Generate preview instead of final render
  --skip-validation      Skip video-script.json validation (not recommended)
  --help, -h             Show this help message

Examples:
  node scripts/render-video.js out/video-script.json
  node scripts/render-video.js out/video-script.json --output final.mp4
  node scripts/render-video.js out/video-script.json --preview --quality medium
  node scripts/render-video.js out/video-script.json --skip-validation
    `);
    process.exit(0);
  }

  const scriptPath = args[0];
  const options = {
    output: null,
    composition: 'VideoComposition',
    concurrency: null,
    quality: null,
    preview: false,
    skipValidation: false,
  };

  for (let i = 1; i < args.length; i++) {
    switch (args[i]) {
      case '--output':
        options.output = args[++i];
        break;
      case '--composition':
        options.composition = args[++i];
        break;
      case '--concurrency':
        options.concurrency = parseInt(args[++i], 10);
        break;
      case '--quality':
        options.quality = args[++i];
        break;
      case '--preview':
        options.preview = true;
        break;
      case '--skip-validation':
        options.skipValidation = true;
        break;
      default:
        logWarning(`Unknown option: ${args[i]}`);
    }
  }

  return { scriptPath, options };
}

/**
 * Load and validate video script
 */
function loadVideoScript(scriptPath, options = {}) {
  if (!fs.existsSync(scriptPath)) {
    throw new Error(`Video script not found: ${scriptPath}`);
  }

  const content = fs.readFileSync(scriptPath, 'utf-8');
  const script = JSON.parse(content);

  // Schema validation unless --skip-validation is specified
  if (!options.skipValidation) {
    logInfo('Validating video-script.json against schema...');
    const { validateVideoScript } = require('./validate-video.js');
    const videoSchemaPath = path.join(__dirname, '../schemas/video-script.schema.json');
    const sceneSchemaPath = path.join(__dirname, '../schemas/scene.schema.json');

    const validationResult = validateVideoScript(script, videoSchemaPath, sceneSchemaPath);

    if (!validationResult.valid) {
      logError('Video script validation failed:');
      console.error('');
      validationResult.errors.forEach((error, index) => {
        console.error(`  ${index + 1}. ${error.details || error.message}`);
      });
      console.error('');
      logWarning('Run with --skip-validation to bypass validation (not recommended).');
      throw new Error('Video script validation failed');
    }

    // Display warnings if any
    if (validationResult.warnings && validationResult.warnings.length > 0) {
      logWarning(`${validationResult.warnings.length} warning(s) found:`);
      validationResult.warnings.forEach((warning, index) => {
        console.log(`  ${index + 1}. ${warning.details || warning.message}`);
      });
      console.log('');
    }

    logSuccess('Video script validation passed');
  } else {
    logWarning('Skipping video-script.json validation (--skip-validation)');
  }

  // Basic validation (after schema validation or if validation is skipped)
  if (!script.metadata || !script.scenes || !script.output_settings) {
    throw new Error('Invalid video script: missing required fields (metadata, scenes, output_settings)');
  }

  if (!Array.isArray(script.scenes) || script.scenes.length === 0) {
    throw new Error('Invalid video script: scenes must be a non-empty array');
  }

  return script;
}

/**
 * Validate that resolved path is within allowed roots (Security fix)
 * Prevents path traversal attacks
 */
function isPathWithinRoots(resolvedPath, allowedRoots) {
  const normalizedPath = path.resolve(resolvedPath);
  return allowedRoots.some(root => {
    const normalizedRoot = path.resolve(root);
    return normalizedPath.startsWith(normalizedRoot + path.sep) || normalizedPath === normalizedRoot;
  });
}

/**
 * Resolve asset paths relative to project root
 * Security: Validates paths are within allowed directories
 */
function resolveAssets(script, scriptPath) {
  const scriptDir = path.dirname(path.resolve(scriptPath));
  const projectRoot = process.cwd();

  // Allowed asset roots for security
  const allowedRoots = [scriptDir, projectRoot];

  const resolvedScenes = script.scenes.map(scene => {
    if (!scene.assets || scene.assets.length === 0) {
      return scene;
    }

    const resolvedAssets = scene.assets.map(asset => {
      if (!asset.source) {
        return asset;
      }

      // Security: Reject paths with path traversal attempts
      if (asset.source.includes('..')) {
        logWarning(`Asset path contains '..', rejected for security: ${asset.source}`);
        return asset;
      }

      // Security: Reject absolute paths from untrusted input
      if (path.isAbsolute(asset.source)) {
        logWarning(`Absolute asset paths are not allowed for security: ${asset.source}`);
        return asset;
      }

      // Try relative to script file
      const relativeToScript = path.resolve(scriptDir, asset.source);
      if (isPathWithinRoots(relativeToScript, allowedRoots) && fs.existsSync(relativeToScript)) {
        return { ...asset, source: relativeToScript };
      }

      // Try relative to project root
      const relativeToRoot = path.resolve(projectRoot, asset.source);
      if (isPathWithinRoots(relativeToRoot, allowedRoots) && fs.existsSync(relativeToRoot)) {
        return { ...asset, source: relativeToRoot };
      }

      logWarning(`Asset not found: ${asset.source}`);
      return asset;
    });

    return { ...scene, assets: resolvedAssets };
  });

  return { ...script, scenes: resolvedScenes };
}

/**
 * Calculate total frames from milliseconds
 */
function msToFrames(ms, fps) {
  return Math.ceil((ms / 1000) * fps);
}

/**
 * Get Remotion CLI path
 * Returns { command: string, extraArgs: string[] } for safe spawn usage
 */
function getRemotionCli() {
  // Check if remotion is installed locally
  const localRemotionBin = path.join(process.cwd(), 'node_modules', '.bin', 'remotion');
  if (fs.existsSync(localRemotionBin)) {
    return { command: localRemotionBin, extraArgs: [] };
  }

  // Fallback to npx - split into command and args for shell: false safety
  return { command: 'npx', extraArgs: ['remotion'] };
}

/**
 * Build Remotion CLI command
 */
function buildRenderCommand(script, options) {
  const { output_settings, total_duration_ms } = script;
  const fps = output_settings.fps || 30;
  const totalFrames = msToFrames(total_duration_ms, fps);

  // Determine output path
  const outputPath = options.output || path.join(process.cwd(), 'out', 'video.mp4');
  const outputDir = path.dirname(outputPath);

  // Ensure output directory exists
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
    logInfo(`Created output directory: ${outputDir}`);
  }

  // Build command
  const { command: remotionCommand, extraArgs: remotionExtraArgs } = getRemotionCli();
  const entryPoint = path.join(process.cwd(), 'remotion', 'index.ts');

  // Write props to temp file to avoid CLI argument length limits (Security & Performance fix)
  const propsFile = path.join(os.tmpdir(), `remotion-props-${Date.now()}.json`);
  fs.writeFileSync(propsFile, JSON.stringify({ script }), 'utf-8');

  const args = [
    ...remotionExtraArgs,
    'render',
    entryPoint,
    options.composition,
    outputPath,
    `--props=${propsFile}`,
  ];

  // Add codec
  if (output_settings.codec) {
    args.push(`--codec=${output_settings.codec}`);
  }

  // Add quality settings
  const quality = options.quality || output_settings.quality;
  if (quality) {
    const qualityMap = {
      low: { crf: 28, preset: 'fast' },
      medium: { crf: 23, preset: 'medium' },
      high: { crf: 18, preset: 'slow' },
      ultra: { crf: 15, preset: 'slower' },
    };
    const qualitySettings = qualityMap[quality] || qualityMap.high;
    args.push(`--crf=${qualitySettings.crf}`);
  }

  // Add concurrency
  if (options.concurrency) {
    args.push(`--concurrency=${options.concurrency}`);
  }

  // Add preview mode
  if (options.preview) {
    args.push('--scale=0.5');
    args.push('--every-nth-frame=2');
  }

  return { command: remotionCommand, args, outputPath, totalFrames, fps };
}

/**
 * Execute Remotion render command
 */
function executeRender(command, args) {
  logInfo('Starting Remotion render...');
  const displayCommand = `${command} ${args.join(' ')}`;
  log(`Command: ${displayCommand}`, 'dim');

  try {
    // Use spawn with shell: false for security (prevents command injection)
    // Command is already split properly by getRemotionCli()
    const child = spawn(command, args, {
      stdio: 'inherit',
      shell: false,
    });

    return new Promise((resolve, reject) => {
      child.on('close', (code) => {
        if (code === 0) {
          resolve();
        } else {
          reject(new Error(`Remotion render failed with exit code ${code}`));
        }
      });

      child.on('error', (err) => {
        reject(err);
      });
    });
  } catch (error) {
    throw new Error(`Failed to execute Remotion: ${error.message}`);
  }
}

/**
 * Display render summary
 */
function displaySummary(script, outputPath, renderTimeMs) {
  const { metadata, scenes, output_settings, total_duration_ms } = script;
  const fileStats = fs.existsSync(outputPath) ? fs.statSync(outputPath) : null;
  const fileSizeMB = fileStats ? (fileStats.size / (1024 * 1024)).toFixed(2) : 'N/A';

  log('\n' + '='.repeat(60), 'cyan');
  log('  RENDER COMPLETE', 'bright');
  log('='.repeat(60), 'cyan');

  log('\n📁 Output File:', 'bright');
  log(`   ${outputPath}`, 'green');
  log(`   Size: ${fileSizeMB} MB\n`, 'dim');

  log('📊 Video Details:', 'bright');
  log(`   Title: ${metadata.title}`);
  log(`   Duration: ${(total_duration_ms / 1000).toFixed(1)}s`);
  log(`   Resolution: ${output_settings.width}x${output_settings.height}`);
  log(`   FPS: ${output_settings.fps}`);
  log(`   Codec: ${output_settings.codec || 'h264'}`);
  log(`   Scenes: ${scenes.length}\n`);

  log('⏱️  Performance:', 'bright');
  log(`   Render Time: ${(renderTimeMs / 1000).toFixed(1)}s`);
  log(`   Speed: ${(total_duration_ms / renderTimeMs).toFixed(2)}x realtime\n`);

  log('🎬 Next Steps:', 'bright');
  log(`   Preview: open ${outputPath}`);
  log(`   Studio: npm run remotion\n`);

  log('='.repeat(60), 'cyan');
}

/**
 * Main execution
 */
async function main() {
  const startTime = Date.now();

  try {
    // Parse arguments
    const { scriptPath, options } = parseArgs();

    log('\n🎬 Video Rendering Pipeline', 'bright');
    log('='.repeat(60) + '\n', 'cyan');

    // Load video script
    logInfo(`Loading video script: ${scriptPath}`);
    const script = loadVideoScript(scriptPath, options);
    logSuccess(`Loaded: ${script.metadata.title}`);

    // Resolve assets
    logInfo('Resolving asset paths...');
    const resolvedScript = resolveAssets(script, scriptPath);
    logSuccess('Assets resolved');

    // Build render command
    logInfo('Building Remotion command...');
    const { command, args, outputPath, totalFrames, fps } = buildRenderCommand(resolvedScript, options);
    logSuccess(`Target: ${outputPath} (${totalFrames} frames @ ${fps}fps)`);

    // Execute render
    log('');
    await executeRender(command, args);
    log('');

    // Display summary
    const renderTime = Date.now() - startTime;
    displaySummary(script, outputPath, renderTime);

    process.exit(0);
  } catch (error) {
    log('');
    logError(`Render failed: ${error.message}`);
    log('');
    log('🔍 Troubleshooting:', 'yellow');
    log('  1. Check that Remotion is installed: npm install remotion');
    log('  2. Verify video-script.json is valid: node scripts/validate-video.js <file>');
    log('  3. Ensure all assets exist and are accessible');
    log('  4. Check remotion/index.ts has the correct composition');
    log('');
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = {
  loadVideoScript,
  resolveAssets,
  msToFrames,
  buildRenderCommand,
};
