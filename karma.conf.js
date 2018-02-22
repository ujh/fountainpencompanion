const webpackConfig = require("./config/webpack/test.js");
webpackConfig.entry = null;
module.exports = function(config) {
  config.set({

    // base path that will be used to resolve all patterns (eg. files, exclude)
    basePath: "app/javascript",

    // frameworks to use
    // available frameworks: https://npmjs.org/browse/keyword/karma-adapter
    frameworks: ["mocha", "chai", "sinon"],

    // list of files / patterns to load in the browser
    files: [
      "../../node_modules/babel-polyfill/dist/polyfill.js",
      "test/test_helper.js"
    ],

    // list of files to exclude
    exclude: [
    ],

    // preprocess matching files before serving them to the browser
    // available preprocessors: https://npmjs.org/browse/keyword/karma-preprocessor
    preprocessors: {
      "**/*.jsx": ["webpack", "sourcemap"],
      "**/*.js": ["webpack", "sourcemap"]
    },

    plugins: [
      "karma-*"
    ],

    // test results reporter to use
    // possible values: 'dots', 'progress'
    // available reporters: https://npmjs.org/browse/keyword/karma-reporter
    reporters: ["mocha", "notify", "coverage"],
    coverageReporter: {
      dir: "../../js-coverage/",
      reporters: [
        { type: "html", subdir: "." },
      ]
    },

    mochaReporter: {
      showDiff: true
    },

    // web server port
    port: 9876,

    // enable / disable colors in the output (reporters and logs)
    colors: true,

    // level of logging
    // possible values: config.LOG_DISABLE || config.LOG_ERROR || config.LOG_WARN || config.LOG_INFO || config.LOG_DEBUG
    logLevel: config.LOG_INFO,

    // enable / disable watching file and executing tests whenever any file changes
    autoWatch: true,

    // start these browsers
    // available browser launchers: https://npmjs.org/browse/keyword/karma-launcher
    browsers: ["PhantomJS"],

    // Continuous Integration mode
    // if true, Karma captures browsers, runs the tests and exits
    singleRun: false,

    // Concurrency level
    // how many browser should be started simultaneous
    concurrency: Infinity,

    webpack: {
      devtool: "inline-source-map",
      module: webpackConfig.module,
      plugins: webpackConfig.plugins,
      resolve: webpackConfig.resolve,
      externals: {
        // "jsdom": "window",
        // "react/lib/ExecutionEnvironment": true,
        // "react/lib/ReactContext": true,
        // "react/addons": true
      }
    }
  });
};
