package doc

import (
	"reflect"
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
		newDocApp("./contextdoesnotexsits", "local")
	})
}

func TestCreateApp(t *testing.T) {
	app := newDocApp("./context", "local")

	if app.config.General.Username != "dmk" {
		t.Errorf("app config not loaded")
	}

	app.Run("ps")
}

func TestDocApp_GetComposeFiles(t *testing.T) {
	app := newDocApp("./context", "local")

	expected := []string{
		"context/docker-compose.yml",
		"context/docker-compose.local.yml",
		"context/docker-compose.credentials.yml",
	}
	files := app.getDockerComposeFiles()

	if reflect.DeepEqual(expected, files) == false {
		t.Errorf("%v does not equal %v", files, expected)
	}
}

func TestDocApp_GetTestComposeFiles(t *testing.T) {
	app := newDocApp("./context", "test")

	expected := []string{
		"context/docker-compose.yml",
		"context/docker-compose.test.yml",
		"context/docker-compose.credentials.yml",
	}
	files := app.getDockerComposeFiles()

	if reflect.DeepEqual(expected, files) == false {
		t.Errorf("%v does not equal %v", files, expected)
	}
}

func assertPanic(t *testing.T, f func()) {
	defer func() {
		if r := recover(); r == nil {
			t.Error("The function did not panic")
		}
	}()
	f()
}
