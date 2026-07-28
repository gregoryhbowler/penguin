import { defineConfig } from 'vite';

// Served from https://<user>.github.io/penguin/ — base must match the repo name.
export default defineConfig({
  base: process.env.GITHUB_ACTIONS ? '/penguin/' : '/',
  build: { target: 'es2020', outDir: 'dist' },
});
