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
	Command(arg string) error
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
		color.White("init 	(Indisponível - cluster já ativo)")
	} else {
		color.Green("init	- Inicia o cluster com configuração padrão")
	}
	color.Green("cfgmetallb     - Configura o balanceador de carga MetalLB")
	color.Green("kps         - Instala o Kube Prometheus Stack")
	color.Green("argocd      - Configura o Ingress do ArgoCD")
	color.Red("delete Destroy-cluster - Deleta o cluster")
	color.Magenta("sair - Sair do programa")
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
	case "init":
		if clusterActive {
			color.Yellow("Cluster já está ativo!")
			return
		}
		if err := m.clusterManager.Command(option); err != nil {
			color.Red("Erro: %v", err)
		}
	case "metallb":
		if err := m.clusterManager.Command(option); err != nil {
			color.Red("Erro: %v", err)
		}
	case "kps":
		if err := m.clusterManager.Command(option); err != nil {
			color.Red("Erro: %v", err)
		}
	case "argocd":
		if err := m.clusterManager.Command(option); err != nil {
			color.Red("Erro: %v", err)
		}
	case "status":
		if err := m.clusterManager.ShowStatus(); err != nil {
			color.Red("Erro: %v", err)
		}
	case "show_help":
		if err := m.clusterManager.Command(option); err != nil {
			color.Red("Erro: %v", err)
		}
	case "delete":
		if err := m.clusterManager.DestroyCluster(); err != nil {
			color.Red("Erro: %v", err)
		}
	case "exit", "sair":
		color.Magenta("Saindo...")
		os.Exit(0)
	default:
		color.Yellow("Opção inválida!")
	}
	fmt.Println()
}
