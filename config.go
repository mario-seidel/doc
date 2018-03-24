package main

import (
	"fmt"
	"log"
	"path"
	"io/ioutil"
	"gopkg.in/yaml.v2"
)

type DocConfig struct {
	General struct {
		Username    string `yaml:"username"`
		ProjectName string `yaml:"project_name"`
	}
}

func loadConfig(context string) *DocConfig {
	settingsFile := path.Join(context, "settings.yml")
	configFile, err := ioutil.ReadFile(settingsFile)

	var config DocConfig

	if err != nil {
		log.Fatalf("error loading settings file: %s", err.Error())
	}

	err = yaml.Unmarshal(configFile, &config)

	if err != nil {
		log.Fatalf("error parsing settings: %s", err.Error())
	}

	return &config
}

func (c *DocConfig) Fullname() string {
	return fmt.Sprintf("%s/%s", c.General.Username, c.General.ProjectName)
}
