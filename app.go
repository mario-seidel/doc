package doc

import (
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path"
)

const dockerComposeCmd = "docker-compose"
const dockerComposeFile = "docker-compose.yml"
const dockerComposeFileSchema = "docker-compose.%s.yml"

var allowedEnvironments = [...]string{"local", "test", "staging", "beta", "live"}
var defaultComposeFileEnvs = [...]string{"", "local", "credentials"}

type DocApp struct {
	context string
	env     string
	config  *DocConfig
}

func newDocApp(context, env string) *DocApp {
	config := loadConfig(context)

	if env == "" && config.DefaultEnvironment != "" {
		env = config.DefaultEnvironment
	}

	if err := initEnvironment(context); err != nil {
		log.Fatal(err)
	}

	return &DocApp{context, env, config}
}

// Run a command with the given environment
// doc up local -> docker-compose up -f docker-compose.yml -f docker-compose.local.yml -f docker-compose.credentials.yml
func (app *DocApp) Run(command string, parameters ...string) {

	checkComposerFiles(app.getDockerComposeFiles())

	if err := checkComposerFileExistsByEnv(""); err != nil {
		log.Fatal(err)
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

func checkComposerFiles(filePaths []string) {
	for _, filePath := range filePaths {
		if exist, _ := pathExists(filePath); exist == false {
			log.Fatal("Error compose file does not exist: ", filePath)
		}
	}
}

// Returns all docker-compose files for the current environment
func (app *DocApp) getDockerComposeFiles() []string {
	var composeFiles []string
	var dockerComposePath string

	additionalEnv := append([]string{app.env}, app.config.AdditionalEnvironments...)
	envs := append([]string{""}, additionalEnv...)

	for _, envFile := range envs {
		if envFile == "" {
			dockerComposePath = path.Join(app.context, dockerComposeFile)
		} else {
			dockerComposePath = path.Join(app.context, fmt.Sprintf(dockerComposeFileSchema, envFile))
		}
		composeFiles = append(composeFiles, dockerComposePath)
	}

	return composeFiles
}

// initEnvironment test if the docker-compose command and the given context exists
func initEnvironment(context string) error {
	if !testCommandExists(dockerComposeCmd) {
		log.Fatalf("%s is not installed or not runable. check your executable.", dockerComposeCmd)
	}

	if e, _ := pathExists(context); e == false {
		log.Fatalf("The given context directory '%s' does not exist.", context)
	}

	return nil
}

// checkComposerFileExitsByEnv test is docker-compose.yml and docker-compose.[env].yml exists
func checkComposerFileExistsByEnv(env string) error {

	var dockerComposePath string

	if exist, _ := pathExists(dockerComposePath); exist == false {
		return errors.New(fmt.Sprintf("%s does not exist!", dockerComposePath))
	}

	return nil
}

// test if the command pathExists and is executable
func testCommandExists(command string) bool {
	_, err := exec.LookPath(command)

	return err == nil
}

// pathExists returns whether the given file or directory exists or not
func pathExists(path string) (bool, error) {
	_, err := os.Stat(path)
	if err == nil {
		return true, nil
	}
	if os.IsNotExist(err) {
		return false, nil
	}

	return true, err
}
