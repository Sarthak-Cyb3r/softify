import { Env, TelemetryReport } from './types';
import { BudgetGuard } from './budget';

export async function handleTelemetry(report: TelemetryReport, env: Env): Promise<{ status: number; message: string }> {
  const tier = await BudgetGuard.getBudgetTier(env);

  // Shed load immediately at Tier 1 (70%) and Tier 2 (90%)
  if (tier !== 'TIER_0_NORMAL') {
    BudgetGuard.recordTelemetryShed();
    return { status: 204, message: 'Telemetry shed by budget guard' };
  }

  // Structured logging to Workers Logs (retained in Cloudflare dashboard, 0 D1 write cost)
  console.log(JSON.stringify({
    event: 'CLIENT_TELEMETRY',
    appVersion: report.appVersion,
    osVersion: report.osVersion,
    abi: report.abi,
    errorType: report.errorType,
    redactedMessage: report.redactedMessage.slice(0, 200),
    occurredAt: report.occurredAtMs
  }));

  return { status: 200, message: 'Report accepted' };
}
