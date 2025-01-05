import { fixupConfigRules, fixupPluginRules } from "@eslint/compat";
import prettier from "eslint-plugin-prettier";
import react from "eslint-plugin-react";
import reactHooks from "eslint-plugin-react-hooks";
import globals from "globals";
import babelParser from "@babel/eslint-parser";
import path from "node:path";
import { fileURLToPath } from "node:url";
import js from "@eslint/js";
import { FlatCompat } from "@eslint/eslintrc";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const compat = new FlatCompat({
  baseDirectory: __dirname,
  recommendedConfig: js.configs.recommended,
  allConfig: js.configs.all
});

export default [
  ...fixupConfigRules(
    compat.extends(
      "eslint:recommended",
      "plugin:react/recommended",
      "plugin:react-hooks/recommended"
    )
  ).map((config) => ({
    ...config,
    files: ["**/*.js", "**/*.jsx"]
  })),
  {
    ignores: [".yarn/"]
  },
  {
    ignores: ["app/assets/builds/"]
  },
  {
    ignores: ["coverage/"]
  },
  {
    ignores: ["app/assets/javascripts/js.cookie.js"]
  },
  {
    ignores: ["vendor/"]
  },
  {
    rules: {
      "no-unused-vars": ["error", { caughtErrors: "none" }]
    }
  },
  {
    files: ["**/*.js", "**/*.jsx"],

    plugins: {
      prettier,
      react: fixupPluginRules(react),
      "react-hooks": fixupPluginRules(reactHooks)
    },

    languageOptions: {
      globals: {
        ...globals.browser
      },

      parser: babelParser,
      ecmaVersion: "latest",
      sourceType: "script",

      parserOptions: {
        ecmaFeatures: {
          jsx: true
        },
        sourceType: "module"
      }
    },

    settings: {
      react: {
        version: "detect"
      }
    },

    rules: {
      "react/prop-types": "off",
      "prettier/prettier": "error",
      "react-hooks/rules-of-hooks": "error",
      "react-hooks/exhaustive-deps": "error"
    }
  },
  {
    files: ["app/assets/javascripts/**/*.js"],

    languageOptions: {
      globals: {
        $: true,
        Cookies: true,
        clicky: true
      }
    }
  },
  {
    files: ["**/*.spec.js", "**/*.spec.jsx"],

    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.jest,
        ...globals.node
      }
    }
  },
  {
    files: ["**/*.config.js"],

    languageOptions: {
      globals: {
        ...globals.node
      }
    }
  }
];
