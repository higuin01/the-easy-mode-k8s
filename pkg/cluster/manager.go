package cluster

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/fatih/color"
)

// Manager handles cluster operations
type Manager struct {
	config Config
}

// Config defines the interface for configuration
type Config interface {
	GetScriptPath(string) string
}

// NewManager creates a new cluster manager
func NewManager(config Config) *Manager {
	return &Manager{
		config: config,
	}
}

// RunScript executes a script and shows real-time output
func (m *Manager) RunScript(scriptName string) error {
	scriptPath := m.config.GetScriptPath(scriptName)
	cmd := exec.Command("bash", scriptPath)
	cmd.Stderr = os.Stderr

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("failed to create stdout pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start script: %w", err)
	}

	scanner := bufio.NewScanner(stdout)
	for scanner.Scan() {
		fmt.Println(scanner.Text())
	}

	if err := cmd.Wait(); err != nil {
		return fmt.Errorf("script execution failed: %w", err)
	}
	return nil
}

// GetClusterStatus checks if the cluster is active
func (m *Manager) GetClusterStatus() (bool, error) {
	cmd := exec.Command("vagrant", "status", "--machine-readable")
	var out strings.Builder
	cmd.Stdout = &out
	
	if err := cmd.Run(); err != nil {
		return false, fmt.Errorf("failed to get vagrant status: %w", err)
	}
	
	return strings.Contains(out.String(), "master-1,state,running"), nil
}

// StartCluster initializes the Kubernetes cluster
func (m *Manager) StartCluster() error {
	color.Cyan("Iniciando cluster...")
	if err := m.RunScript("up-k8s.sh"); err != nil {
		return fmt.Errorf("failed to start cluster: %w", err)
	}
	color.Green("Cluster iniciado com sucesso!")
	return nil
}

// DestroyCluster removes the cluster
func (m *Manager) DestroyCluster() error {
	color.Cyan("Deletando cluster...")
	if err := m.RunScript("destroy-cluster.sh"); err != nil {
		return fmt.Errorf("failed to destroy cluster: %w", err)
	}
	color.Green("Cluster deletado com sucesso!")
	return nil
}

// ShowStatus displays the current cluster status
func (m *Manager) ShowStatus() error {
	color.Cyan("Status do cluster:")
	if err := m.RunScript("status-k8s.sh"); err != nil {
		return fmt.Errorf("failed to get cluster status: %w", err)
	}
	color.Green("************************************")
	return nil
}