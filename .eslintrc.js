module.exports = {
  env: {
    es2021: true,  // ✅ ES2021 이상 설정
    node: true
  },
  extends: ["eslint:recommended"],
  parserOptions: {
    ecmaVersion: 2021,  // ✅ 또는 2022 이상
    sourceType: "module"
  },
  rules: {}
};

