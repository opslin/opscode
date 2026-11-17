// Files the indexer never opens, never lists and never stores: keys, certificates,
// environment files and credentials. Matched by name only (the file is not read).

const SECRET_EXT = new Set([".pem", ".key", ".p12", ".pfx", ".keystore", ".jks", ".cer", ".crt", ".der", ".ppk", ".asc", ".gpg", ".kdbx", ".mobileprovision"]);
const SECRET_NAME = [
  /^\.env(\..*)?$/i, /^\.envrc$/i, /^id_(rsa|dsa|ecdsa|ed25519)(\.pub)?$/i, /credentials?/i, /secrets?\.(json|ya?ml|toml|txt)$/i, /^\.npmrc$/i, /^\.pypirc$/i, /^\.netrc$/i,
  /^google-services\.json$/i, /^GoogleService-Info\.plist$/i, /service[-_]?account.*\.json$/i, /^firebase-adminsdk.*\.json$/i, /\.tfvars$/i, /^terraform\.tfstate/i, /^kubeconfig/i,
];

const CODE_EXT = new Set([".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".dart", ".go", ".py", ".kt", ".java", ".swift", ".php", ".rb", ".cs", ".rs", ".sql", ".vue", ".md"]);
// A word like "credentials" in a source file's name (admin-credentials.repository.ts) is code, not a secret.
const WEAK = [/credentials?/i, /secrets?\.(json|ya?ml|toml|txt)$/i];

export function isSecretName(name: string): boolean {
  const lower = name.toLowerCase();
  const dot = lower.lastIndexOf(".");
  const ext = dot >= 0 ? lower.slice(dot) : "";
  if (SECRET_EXT.has(ext)) return true;
  if (CODE_EXT.has(ext) && WEAK.some((re) => re.test(name)) && !/^\.env/i.test(name)) return false;
  return SECRET_NAME.some((re) => re.test(name));
}
