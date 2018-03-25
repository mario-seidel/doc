package doc

import (
	"fmt"
	"gopkg.in/alecthomas/kingpin.v2"
)

var (
	verbose = kingpin.Flag("verbose", "Verbose mode.").Short('v').Bool()
	command    = kingpin.Arg("command", "Name of command.").Required().String()
)

func main() {
	kingpin.Parse()

	fmt.Printf("hello the command was: %s!", *command)
}
