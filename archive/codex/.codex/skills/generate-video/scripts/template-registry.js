#!/usr/bin/env node
/**
 * Template Registry
 *
 * Manages video script templates:
 *   - List available templates
 *   - Load template by name
 *   - Validate template format
 *   - Replace template variables
 *
 * Usage:
 *   const { getTemplate, listTemplates } = require('./template-registry');
 *
 *   // List all templates
 *   const templates = listTemplates();
 *
 *   // Load specific template
 *   const template = getTemplate('teaser-90s');
 *
 *   // Load with variable substitution
 *   const script = getTemplate('teaser-90s', {
 *     PROJECT_NAME: 'MyApp',
 *     TAGLINE: 'Simplify your workflow',
 *     // ...
 *   });
 */

const fs = require('fs');
const path = require('path');

const TEMPLATES_DIR = path.join(__dirname, '..', 'templates');

/**
 * Template metadata registry
 */
const TEMPLATE_METADATA = {
  'teaser-90s': {
    name: 'teaser-90s',
    title: '90-Second LP Teaser',
    description: 'Landing page teaser following pain→solution→CTA narrative',
    duration_ms: 90000,
    scenes: 5,
    video_type: 'lp-teaser',
    funnel: 'awareness → interest',
    use_cases: ['Landing pages', 'Social media ads', 'Product announcements'],
    structure: 'Hook(5s) → Problem+Promise(10s) → Workflow(40s) → Differentiator(15s) → CTA(20s)',
  },
  'intro-3min': {
    name: 'intro-3min',
    title: '3-Minute Intro Demo',
    description: 'Complete use case walkthrough for product introduction',
    duration_ms: 180000,
    scenes: 7,
    video_type: 'intro-demo',
    funnel: 'interest → consideration',
    use_cases: ['Product demos', 'Tutorials', 'Webinar intros', 'Sales presentations'],
    structure: 'Hook(10s) → UseCase(20s) → Demo(110s) → Objection(30s) → CTA(10s)',
  },
};

/**
 * List all available templates
 *
 * @returns {Array<Object>} Template metadata
 */
function listTemplates() {
  return Object.values(TEMPLATE_METADATA);
}

/**
 * Get template metadata by name
 *
 * @param {string} templateName - Template name (without .json extension)
 * @returns {Object|null} Template metadata or null if not found
 */
function getTemplateMetadata(templateName) {
  return TEMPLATE_METADATA[templateName] || null;
}

/**
 * Load template file
 *
 * @param {string} templateName - Template name (without .json extension)
 * @returns {Object} Template object
 * @throws {Error} If template not found or invalid
 */
function loadTemplateFile(templateName) {
  // Path traversal protection: only allow known templates
  if (!TEMPLATE_METADATA[templateName]) {
    throw new Error(
      `Template not found: ${templateName}\nAvailable templates: ${Object.keys(TEMPLATE_METADATA).join(', ')}`
    );
  }

  // Additional safeguard: reject any path-like characters
  if (templateName.includes('/') || templateName.includes('\\') || templateName.includes('..')) {
    throw new Error(`Invalid template name: ${templateName}`);
  }

  const templatePath = path.join(TEMPLATES_DIR, `${templateName}.json`);

  if (!fs.existsSync(templatePath)) {
    throw new Error(
      `Template file missing: ${templateName}.json\nExpected at: ${templatePath}`
    );
  }

  try {
    const content = fs.readFileSync(templatePath, 'utf-8');
    const template = JSON.parse(content);

    // Basic validation
    if (!template.metadata || !template.scenes || !template.output_settings) {
      throw new Error('Invalid template: missing required fields (metadata, scenes, output_settings)');
    }

    return template;
  } catch (error) {
    if (error instanceof SyntaxError) {
      throw new Error(`Invalid JSON in template ${templateName}: ${error.message}`);
    }
    throw error;
  }
}

/**
 * Replace template variables
 *
 * Recursively replaces {{VARIABLE_NAME}} placeholders in template
 *
 * @param {any} obj - Object to process
 * @param {Object} variables - Variable values
 * @returns {any} Object with variables replaced
 */
function replaceVariables(obj, variables) {
  if (typeof obj === 'string') {
    // Replace all {{VARIABLE}} patterns
    return obj.replace(/\{\{([A-Z_]+)\}\}/g, (match, varName) => {
      if (variables.hasOwnProperty(varName)) {
        return variables[varName];
      }
      // Keep placeholder if variable not provided
      return match;
    });
  }

  if (Array.isArray(obj)) {
    return obj.map((item) => replaceVariables(item, variables));
  }

  if (obj !== null && typeof obj === 'object') {
    const result = {};
    for (const key in obj) {
      // Skip _template_variables field
      if (key === '_template_variables') {
        continue;
      }
      result[key] = replaceVariables(obj[key], variables);
    }
    return result;
  }

  return obj;
}

/**
 * Get default variables from template
 *
 * @param {Object} template - Template object
 * @returns {Object} Default variable descriptions
 */
function getDefaultVariables(template) {
  return template._template_variables || {};
}

/**
 * Get required variables from template
 *
 * Extracts all {{VARIABLE}} patterns from template
 *
 * @param {Object} template - Template object
 * @returns {Set<string>} Set of variable names
 */
function getRequiredVariables(template) {
  const variables = new Set();
  const jsonString = JSON.stringify(template);
  const matches = jsonString.matchAll(/\{\{([A-Z_]+)\}\}/g);

  for (const match of matches) {
    variables.add(match[1]);
  }

  return variables;
}

/**
 * Get template with optional variable substitution
 *
 * @param {string} templateName - Template name
 * @param {Object} [variables] - Optional variables to replace
 * @returns {Object} Template object (with variables replaced if provided)
 * @throws {Error} If template not found or invalid
 */
function getTemplate(templateName, variables = null) {
  const template = loadTemplateFile(templateName);

  if (variables) {
    return replaceVariables(template, variables);
  }

  return template;
}

/**
 * Validate template completeness
 *
 * Checks if all required variables have been replaced
 *
 * @param {Object} script - Video script object
 * @returns {Object} { valid: boolean, missingVariables: string[] }
 */
function validateTemplateCompleteness(script) {
  const jsonString = JSON.stringify(script);
  const unreplacedVariables = new Set();
  const matches = jsonString.matchAll(/\{\{([A-Z_]+)\}\}/g);

  for (const match of matches) {
    unreplacedVariables.add(match[1]);
  }

  return {
    valid: unreplacedVariables.size === 0,
    missingVariables: Array.from(unreplacedVariables),
  };
}

/**
 * CLI Interface
 */
if (require.main === module) {
  const args = process.argv.slice(2);
  const command = args[0];

  if (!command || command === '--help' || command === '-h') {
    console.log(`
Template Registry - Video Script Template Manager

Usage:
  node scripts/template-registry.js <command> [options]

Commands:
  list                    List all available templates
  info <template-name>    Show template information
  load <template-name>    Load template JSON (with placeholders)
  variables <template>    List required variables for a template

Examples:
  node scripts/template-registry.js list
  node scripts/template-registry.js info teaser-90s
  node scripts/template-registry.js variables intro-3min
    `);
    process.exit(0);
  }

  try {
    switch (command) {
      case 'list': {
        const templates = listTemplates();
        console.log('\n📋 Available Templates:\n');
        templates.forEach((t) => {
          console.log(`  ${t.name}`);
          console.log(`    ${t.title} - ${t.duration_ms / 1000}s`);
          console.log(`    ${t.description}`);
          console.log(`    Use cases: ${t.use_cases.join(', ')}`);
          console.log('');
        });
        break;
      }

      case 'info': {
        const templateName = args[1];
        if (!templateName) {
          console.error('Error: Template name required');
          process.exit(1);
        }

        const metadata = getTemplateMetadata(templateName);
        if (!metadata) {
          console.error(`Error: Template '${templateName}' not found`);
          console.log(`Available: ${Object.keys(TEMPLATE_METADATA).join(', ')}`);
          process.exit(1);
        }

        console.log('\n📄 Template Information:\n');
        console.log(`  Name: ${metadata.name}`);
        console.log(`  Title: ${metadata.title}`);
        console.log(`  Description: ${metadata.description}`);
        console.log(`  Duration: ${metadata.duration_ms / 1000}s`);
        console.log(`  Scenes: ${metadata.scenes}`);
        console.log(`  Video Type: ${metadata.video_type}`);
        console.log(`  Funnel: ${metadata.funnel}`);
        console.log(`  Use Cases: ${metadata.use_cases.join(', ')}`);
        console.log(`  Structure: ${metadata.structure}`);
        console.log('');
        break;
      }

      case 'load': {
        const templateName = args[1];
        if (!templateName) {
          console.error('Error: Template name required');
          process.exit(1);
        }

        const template = loadTemplateFile(templateName);
        console.log(JSON.stringify(template, null, 2));
        break;
      }

      case 'variables': {
        const templateName = args[1];
        if (!templateName) {
          console.error('Error: Template name required');
          process.exit(1);
        }

        const template = loadTemplateFile(templateName);
        const requiredVars = getRequiredVariables(template);
        const defaultVars = getDefaultVariables(template);

        console.log('\n📝 Required Variables:\n');
        requiredVars.forEach((varName) => {
          const description = defaultVars[varName] || 'No description';
          console.log(`  ${varName}`);
          console.log(`    ${description}`);
          console.log('');
        });
        break;
      }

      default:
        console.error(`Unknown command: ${command}`);
        console.log('Run with --help for usage information');
        process.exit(1);
    }
  } catch (error) {
    console.error(`\nError: ${error.message}\n`);
    process.exit(1);
  }
}

module.exports = {
  listTemplates,
  getTemplateMetadata,
  getTemplate,
  loadTemplateFile,
  replaceVariables,
  getRequiredVariables,
  getDefaultVariables,
  validateTemplateCompleteness,
};
