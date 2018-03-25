package doc

import (
	"testing"
)

func TestDocApp_TestWrongCommand(t *testing.T) {
	cmdExists := testCommandExists("thiscommandshouldnotexist")

	if cmdExists {
		t.Errorf("the command 'thiscommandshouldnotexist' should not exist")
	}
}

func TestDocApp_WrongContext(t *testing.T) {
	assertPanic(t, func() {
		newDocApp("./contextdoesnotexsits")
	})
}

func TestCreateApp(t *testing.T) {
	app := newDocApp("./context")

	if app.config.General.Username != "dmk" {
		t.Errorf("app config not loaded")
	}

	app.Run("ps")
}

func assertPanic(t *testing.T, f func()) {
	defer func() {
		if r := recover(); r == nil {
			t.Error("The function did not panic")
		}
	}()
	f()
}
