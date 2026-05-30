package templates

import (
	"strings"
	"testing"
)

func TestGenerateMainCaddyfileUsesStandardCaddyDirectives(t *testing.T) {
	out, err := GenerateMainCaddyfile(&MainCaddyfileConfig{
		AdminEmail: "admin@example.com",
		Sites: []SiteConfig{
			{
				Domain:       "example.com",
				Username:     "siteuser",
				DocumentRoot: "/home/siteuser/apps/example_com/public",
				PHPEnabled:   true,
				SSLEnabled:   true,
			},
		},
	})
	if err != nil {
		t.Fatalf("GenerateMainCaddyfile() error = %v", err)
	}
	for _, legacy := range []string{"php_server", "fastcp_ui", "litecp_ui", "fastcp {", "litecp {"} {
		if strings.Contains(out, legacy) {
			t.Fatalf("generated Caddyfile contains legacy directive %q:\n%s", legacy, out)
		}
	}
	for _, required := range []string{"admin localhost:2019", "root * /home/siteuser/apps/example_com/public", "php_fastcgi unix//home/siteuser/.litecp/run/php.sock", "-X-Powered-By", "file_server"} {
		if !strings.Contains(out, required) {
			t.Fatalf("generated Caddyfile missing %q:\n%s", required, out)
		}
	}
}
