package config

import (
	"os"
	"path/filepath"
)

// Config holds the application configuration
type Config struct {
	ScriptsDir     string
	MasterNodeName string
	LogFile        string
}

// NewConfig creates a new configuration with default values
func NewConfig() *Config {
	return &Config{
		ScriptsDir:     "scripts/",
		MasterNodeName: "master-1",
		LogFile:        "cluster-manager.log",
	}
}

// ValidateScriptsDir ensures the scripts directory exists
func (c *Config) ValidateScriptsDir() error {
	if _, err := os.Stat(c.ScriptsDir); os.IsNotExist(err) {
		return err
	}
	return nil
}

// GetScriptPath returns the full path to a script
func (c *Config) GetScriptPath(scriptName string) string {
	return filepath.Join(c.ScriptsDir, scriptName)
}