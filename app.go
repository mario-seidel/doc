package doc

import (
	"fmt"
	"log"
	"os/exec"
	"os"
)

const dockerComposeCmd = "docker-compose"

type DocApp struct {
	context string
	config  *DocConfig
}

func newDocApp(context string) *DocApp {
	if e, _ := exists(context); e == false {
		log.Panicf("The given context directory '%s' does not exist.", context)
	}

	config := loadConfig(context)

	return &DocApp{context, config}
}

func (app *DocApp) Run(command string, parameters ...string) {
	if !testCommandExists(dockerComposeCmd) {
		log.Panicf("%s is not installed or not runable. check your executable.", dockerComposeCmd)
	}

	parameters = append(parameters, command)
	cmd := exec.Command(dockerComposeCmd, parameters...)
	//set working dir
	cmd.Dir = app.context

	stdoutStderr, err := cmd.CombinedOutput()

	if err != nil {
		log.Fatalf("%s: %s", err, stdoutStderr)
	}
	fmt.Printf("%s\n", stdoutStderr)
}

//test if the command exists and is executable
func testCommandExists(command string) bool {
	_, err := exec.LookPath(command)

	return err == nil
}

// exists returns whether the given file or directory exists or not
func exists(path string) (bool, error) {
	_, err := os.Stat(path)
	if err == nil { return true, nil }
	if os.IsNotExist(err) { return false, nil }
	return true, err
}