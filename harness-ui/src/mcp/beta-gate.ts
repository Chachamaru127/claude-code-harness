/**
 * Beta Gate - Polar ライセンスキー検証
 *
 * Polar.sh のライセンスキー API を使用してベータアクセスを制御します。
 * https://polar.sh/docs/features/benefits/license-keys
 */

// Polar Organization ID
const POLAR_ORGANIZATION_ID = '54443411-11a2-45b0-9473-7aa37f96a677';

// 開発者モード（常にアクセス可能）
const DEV_MODE = process.env.HARNESS_UI_DEV === 'true';

// Polar API エンドポイント
const POLAR_LICENSE_VALIDATE_URL = 'https://api.polar.sh/v1/customer-portal/license-keys/validate';

export interface BetaValidationResult {
  valid: boolean;
  reason: string;
  licenseKey?: string;
  customerId?: string;
  expiresAt?: string;
}

interface PolarLicenseResponse {
  id: string;
  status: string;
  key: string;
  customer_id: string;
  expires_at: string | null;
  limit_activations: number | null;
  usage: number;
  limit_usage: number | null;
  validations: number;
  last_validated_at: string | null;
}

/**
 * Polar API でライセンスキーを検証
 */
async function validateWithPolar(licenseKey: string): Promise<BetaValidationResult> {
  try {
    const response = await fetch(POLAR_LICENSE_VALIDATE_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        key: licenseKey,
        organization_id: POLAR_ORGANIZATION_ID,
      }),
    });

    if (!response.ok) {
      return {
        valid: false,
        reason: `License validation failed: ${response.status}`,
        licenseKey,
      };
    }

    const data = await response.json() as PolarLicenseResponse;

    // ステータスチェック
    if (data.status !== 'granted') {
      return {
        valid: false,
        reason: `License status: ${data.status}`,
        licenseKey,
      };
    }

    // 有効期限チェック
    if (data.expires_at) {
      const expiresAt = new Date(data.expires_at);
      if (expiresAt < new Date()) {
        return {
          valid: false,
          reason: 'License expired',
          licenseKey,
          expiresAt: data.expires_at,
        };
      }
    }

    return {
      valid: true,
      reason: 'Valid Polar license',
      licenseKey,
      customerId: data.customer_id,
      expiresAt: data.expires_at ?? undefined,
    };
  } catch (error) {
    return {
      valid: false,
      reason: `Network error: ${error instanceof Error ? error.message : 'Unknown'}`,
      licenseKey,
    };
  }
}

/**
 * ベータアクセスを検証
 */
export async function validateBetaAccess(): Promise<BetaValidationResult> {
  // 開発者モードは常に有効
  if (DEV_MODE) {
    return {
      valid: true,
      reason: 'Developer mode enabled',
    };
  }

  const licenseKey = process.env.HARNESS_BETA_CODE;

  // ライセンスキーが設定されていない
  if (!licenseKey) {
    return {
      valid: false,
      reason: 'License key not provided',
    };
  }

  // Polar API で検証
  return validateWithPolar(licenseKey);
}

/**
 * ベータアクセス拒否時のメッセージを表示
 */
export function showBetaAccessDenied(result: BetaValidationResult): void {
  console.error('');
  console.error('╔═══════════════════════════════════════════════════════════╗');
  console.error('║           harness-ui - Beta Access Required               ║');
  console.error('╠═══════════════════════════════════════════════════════════╣');
  console.error('║                                                           ║');
  console.error('║  This feature is currently in beta testing.               ║');
  console.error('║  A valid license key is required to access harness-ui.    ║');
  console.error('║                                                           ║');
  console.error('║  To get access:                                           ║');
  console.error('║  1. Subscribe at https://polar.sh/cc-harness              ║');
  console.error('║  2. Set HARNESS_BETA_CODE environment variable            ║');
  console.error('║                                                           ║');
  console.error('║  Example (.mcp.json):                                     ║');
  console.error('║  {                                                        ║');
  console.error('║    "env": {                                               ║');
  console.error('║      "HARNESS_BETA_CODE": "YOUR-LICENSE-KEY"              ║');
  console.error('║    }                                                      ║');
  console.error('║  }                                                        ║');
  console.error('║                                                           ║');
  console.error('╚═══════════════════════════════════════════════════════════╝');
  console.error('');
  console.error(`[harness-ui] ${result.reason}`);

  if (result.licenseKey) {
    console.error(`[harness-ui] Provided key: ${result.licenseKey.substring(0, 8)}...`);
  }
}
