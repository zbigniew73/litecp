package templates

import (
	"strings"
	"testing"
)

func TestGenerateWPConfigIncludesLiteCPDefaults(t *testing.T) {
	out, err := GenerateWPConfig(&WordPressConfig{
		DBName:     "wp_db",
		DBUser:     "wp_user",
		DBPassword: "secret-password",
	})
	if err != nil {
		t.Fatalf("GenerateWPConfig() error = %v", err)
	}
	for _, required := range []string{
		"define( 'DB_NAME', 'wp_db' );",
		"define( 'DB_USER', 'wp_user' );",
		"define( 'DB_PASSWORD', 'secret-password' );",
		"define( 'DB_HOST', '127.0.0.1' );",
		"define( 'DISALLOW_FILE_EDIT', true );",
		"define( 'FORCE_SSL_ADMIN', true );",
		"HTTP_X_FORWARDED_PROTO",
		"require_once ABSPATH . 'wp-settings.php';",
	} {
		if !strings.Contains(out, required) {
			t.Fatalf("generated wp-config missing %q:\n%s", required, out)
		}
	}
	if strings.Contains(out, "{{") || strings.Contains(out, "}}") {
		t.Fatalf("generated wp-config contains unrendered template markers:\n%s", out)
	}
}
