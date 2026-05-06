/**
 * @file
 * @author Tomáš Chochola <tomaschochola@tomaschochola.cz>
 * @copyright © 2026 Tomáš Chochola <tomaschochola@tomaschochola.cz>
 *
 * @license CC-BY-ND-4.0
 *
 * @see {@link https://creativecommons.org/licenses/by-nd/4.0/} License
 * @see {@link https://github.com/tomaschochola} GitHub Profile
 * @see {@link https://github.com/sponsors/tomaschochola} GitHub Sponsors
 */

import { ESLintConfigBuilder, filePatterns } from '@tomaschochola/tooling-eslint';

const typescriptFiles = [...filePatterns.allTypeScriptFiles, ...filePatterns.allTsxFiles];
const javascriptFiles = [...filePatterns.allJavaScriptFiles, ...filePatterns.allJsxFiles];

// eslint-disable-next-line no-restricted-exports
export default new ESLintConfigBuilder()
  .addNodeGlobals()
  .addGlobalIgnores(filePatterns.defaultIgnorePatterns)
  .addGlobalIgnores(['node_modules', 'dist'])
  .addJavaScriptRecommendedRules()
  .addJavaScriptPolicyRules()
  .addTypeScriptStrictTypeCheckedRules({ files: typescriptFiles })
  .addTypeScriptStylisticTypeCheckedRules({ files: typescriptFiles })
  .enableTypeScriptProjectService({ files: typescriptFiles })
  .addTypeScriptPolicyRules({ files: typescriptFiles })
  .disableTypeScriptTypeChecking({ files: javascriptFiles })
  .addStylisticCustomizedRules()
  .addStylisticPolicyRules()
  .disableStylisticLegacyRules()
  .addSonarJsRecommendedRules()
  .addSonarJsPolicyOverrides()
  .toConfig();
