import java.net.HttpURLConnection
import java.net.URL

String targetUrl = 'https://jenkins2-usw2a.awsc.leadfusion.com/login'

println("Checking URL: ${targetUrl}")

HttpURLConnection conn = (HttpURLConnection) new URL(targetUrl).openConnection()
conn.setInstanceFollowRedirects(false)
conn.setRequestMethod('GET')
conn.setConnectTimeout(15000)
conn.setReadTimeout(15000)

int code = conn.getResponseCode()
println("HTTP status: ${code}")

List<Integer> allowed = [200, 301, 302, 403]

if (!allowed.contains(code)) {
    throw new RuntimeException("Unexpected HTTP status ${code} for ${targetUrl}")
}

println("Smoke test passed for ${targetUrl}")