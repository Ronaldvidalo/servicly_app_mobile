module.exports = {
  root: true,
  env: {
    es2017: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  parserOptions: {
    "ecmaVersion": 2020,
  },
  rules: {
    "quotes": ["error", "double"],
    "require-jsdoc": 0,
    "max-len": ["warn", {"code": 120}],
    "indent": ["error", 2],
    "object-curly-spacing": ["error", "never"],
  },
};
