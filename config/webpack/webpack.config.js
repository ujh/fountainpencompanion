const { webpackConfig, inliningCss } = require('shakapacker');
const ReactRefreshWebpackPlugin = require('@pmmmwh/react-refresh-webpack-plugin');

// See the shakacode/shakapacker README and docs directory for advice on customizing your webpackConfig.
// https://github.com/shakacode/shakapacker#webpack-configuration

const isDevelopment = process.env.NODE_ENV !== 'production';
if (isDevelopment && inliningCss) {
  webpackConfig.plugins.push(
    new ReactRefreshWebpackPlugin({
      overlay: {
        sockPort: webpackConfig.devServer.port,
      },
    })
  );
}

module.exports = webpackConfig;
