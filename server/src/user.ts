import { Env, DeviceContext } from './types';
import { BudgetGuard } from './budget';

export async function handleUserExport(device: DeviceContext, env: Env): Promise<{ status: number; data: any }> {
  BudgetGuard.recordD1Read(2);

  const devRow = await env.DB.prepare(
    'SELECT id, created_at, last_active_at FROM devices WHERE id = ?'
  ).bind(device.deviceId).first();

  const syncRows = await env.DB.prepare(
    'SELECT item_id, item_type, payload, hlc_timestamp, is_deleted, version, updated_at FROM library_sync WHERE device_id = ?'
  ).bind(device.deviceId).all();

  return {
    status: 200,
    data: {
      account: devRow,
      library: syncRows.results || [],
      exportedAt: Date.now()
    }
  };
}

export async function handleUserDelete(device: DeviceContext, env: Env): Promise<{ status: number; message: string }> {
  BudgetGuard.recordD1Write(3);

  // Cascading delete: library_sync, sessions, and device
  await env.DB.batch([
    env.DB.prepare('DELETE FROM library_sync WHERE device_id = ?').bind(device.deviceId),
    env.DB.prepare('DELETE FROM sessions WHERE device_id = ?').bind(device.deviceId),
    env.DB.prepare('DELETE FROM devices WHERE id = ?').bind(device.deviceId)
  ]);

  return {
    status: 200,
    message: 'All device data and associated library records permanently deleted.'
  };
}
