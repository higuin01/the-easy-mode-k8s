package ui

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"github.com/fatih/color"
)

// Menu handles the user interface
type Menu struct {
	clusterManager ClusterManager
	scanner        *bufio.Scanner
}

// ClusterManager defines the interface for cluster operations
type ClusterManager interface {
	GetClusterStatus() (bool, error)
	StartCluster() error
	DestroyCluster() error
	ShowStatus() error
}

// NewMenu creates a new menu instance
func NewMenu(manager ClusterManager) *Menu {
	return &Menu{
		clusterManager: manager,
		scanner:        bufio.NewScanner(os.Stdin),
	}
}

// PrintHeader shows the application header with cluster status
func (m *Menu) PrintHeader() {
	color.Cyan("=== Gerenciador de Cluster Kubernetes ===")
	active, err := m.clusterManager.GetClusterStatus()
	if err != nil {
		color.Red("Erro ao obter status do cluster: %v", err)
		return
	}
	
	if active {
		color.Green("Cluster: ATIVO")
	} else {
		color.Yellow("Cluster: INATIVO")
	}
	fmt.Println()
}

// PrintMenu shows the available options
func (m *Menu) PrintMenu(clusterActive bool) {
	color.Cyan("Escolha uma opção:")
	if clusterActive {
		color.White("  1. Up K8s (Indisponível - cluster já ativo)")
	} else {
		color.Green("  1. Up K8s - Inicia o cluster com configuração padrão")
	}
	color.Green("  2. Status - Mostra o status do cluster")
	color.Red("  delete. Destroy-cluster - Deleta o cluster")
	color.Magenta("  9. Sair")
	fmt.Println()
}

// GetUserInput reads and validates user input
func (m *Menu) GetUserInput() string {
	color.White("Digite sua opção: ")
	m.scanner.Scan()
	return strings.TrimSpace(m.scanner.Text())
}

// ExecuteOption processes the user's choice
func (m *Menu) ExecuteOption(option string, clusterActive bool) {
	switch option {
	case "1":
		if clusterActive {
			color.Yellow("Cluster já está ativo!")
			return
		}
		if err := m.clusterManager.StartCluster(); err != nil {
			color.Red("Erro: %v", err)
		}
	
	case "2":
		if err := m.clusterManager.ShowStatus(); err != nil {
			color.Red("Erro: %v", err)
		}
	
	case "delete":
		if err := m.clusterManager.DestroyCluster(); err != nil {
			color.Red("Erro: %v", err)
		}
	
	case "9":
		color.Magenta("Saindo...")
		os.Exit(0)
	
	default:
		color.Yellow("Opção inválida!")
	}
	fmt.Println()
}