import { Env, DeviceContext } from './types';
import { BudgetGuard } from './budget';

export async function handleUserExport(device: DeviceContext, env: Env): Promise<{ status: number; data: any }> {
  BudgetGuard.recordD1Read(2);

  const devRow = await env.DB.prepare(
    'SELECT id, COALESCE(account_id, id) AS account_id, created_at, last_active_at FROM devices WHERE id = ?'
  ).bind(device.deviceId).first();

  const syncRows = await env.DB.prepare(
    'SELECT item_id, item_type, payload, hlc_timestamp, is_deleted, version, updated_at FROM library_sync WHERE device_id = ?'
  ).bind(device.accountId).all();

  return {
    status: 200,
    data: {
      account: devRow || { id: device.deviceId, account_id: device.accountId },
      library: syncRows.results || [],
      exportedAt: Date.now()
    }
  };
}

export async function handleUserDelete(device: DeviceContext, env: Env): Promise<{ status: number; message: string }> {
  BudgetGuard.recordD1Write(3);

  await env.DB.batch([
    env.DB.prepare('DELETE FROM library_sync WHERE device_id = ?').bind(device.accountId),
    env.DB.prepare(
      'DELETE FROM sessions WHERE device_id IN (SELECT id FROM devices WHERE account_id = ? OR id = ?)'
    ).bind(device.accountId, device.accountId),
    env.DB.prepare('DELETE FROM devices WHERE account_id = ? OR id = ?').bind(device.accountId, device.accountId)
  ]);

  return {
    status: 200,
    message: 'All account data and associated library records permanently deleted.'
  };
}
