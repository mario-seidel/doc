package doc

import "testing"

func TestDocConfig_Fullname(t *testing.T) {
	config := loadConfig("./context")

	fullname := config.Fullname()

	if fullname != "dmk/my-awesome-project" {
		t.Errorf("fullname does not match: %s", fullname)
	}
}