const PROBE_TIMEOUT = 5000

export async function serverReachable() {
  try {
    const response = await fetch("/up", { cache: "no-store", signal: AbortSignal.timeout(PROBE_TIMEOUT) })
    return response.ok
  } catch {
    return false
  }
}
