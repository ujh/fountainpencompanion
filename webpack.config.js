// @ts-check
const path = require("path");
const webpack = require("webpack");
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const RemoveEmptyScriptsPlugin = require("webpack-remove-empty-scripts");

const mode =
  process.env.NODE_ENV === "development" ? "development" : "production";

/**
 * @typedef {import("webpack").Configuration} WebpackConfiguration
 * @type WebpackConfiguration
 */
module.exports = {
  mode,
  entry: {
    application: "./app/javascript/application.js",
    admin: "./app/javascript/admin.js"
  },
  module: {
    rules: [
      {
        test: /\.(?:sa|sc|c)ss$/i,
        use: [MiniCssExtractPlugin.loader, "css-loader", "sass-loader"]
      },
      {
        test: /\.(js|jsx|ts|tsx|)$/,
        exclude: /node_modules/,
        use: ["babel-loader"]
      }
    ]
  },
  resolve: {
    extensions: [".js", ".jsx", ".ts", ".tsx", ".scss", ".css"]
  },
  optimization: {
    moduleIds: "deterministic"
  },
  output: {
    filename: "[name].js",
    sourceMapFilename: "[file].map",
    path: path.resolve(__dirname, "app/assets/builds")
  },
  plugins: [
    // @ts-ignore-next-line
    new RemoveEmptyScriptsPlugin(),
    new MiniCssExtractPlugin(),
    new webpack.optimize.LimitChunkCountPlugin({
      maxChunks: 1
    })
  ]
};
