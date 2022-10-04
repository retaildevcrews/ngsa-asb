package main

import (
	"context"
	"flag"
	"os"

	"github.com/spf13/pflag"
	"k8s.io/apimachinery/pkg/runtime"
	cliflag "k8s.io/component-base/cli/flag"
	"k8s.io/component-base/logs"
	"k8s.io/klog/v2"
	"k8s.io/utils/pointer"
	ctrl "sigs.k8s.io/controller-runtime"

	runtimecatalog "sigs.k8s.io/cluster-api/exp/runtime/catalog"
	runtimehooksv1 "sigs.k8s.io/cluster-api/exp/runtime/hooks/api/v1alpha1"
	"sigs.k8s.io/cluster-api/exp/runtime/server"
	infrav1 "sigs.k8s.io/cluster-api/test/infrastructure/docker/api/v1beta1"
)

var (
	catalog = runtimecatalog.New()
	scheme  = runtime.NewScheme()

	setupLog = ctrl.Log.WithName("setup")

	// Flags.
	webhookPort    int
	webhookCertDir string
	logOptions     = logs.NewOptions()
)

func init() {
	// infrav1 in this context is the package that contains the k8s API schema related to docker cluster CRDs.
	// Will need to add the appropriate schema(s) for other types of cluster CRDs, like AKS, when the time comes.
	_ = infrav1.AddToScheme(scheme)

	// Register the RuntimeHook types into the catalog.
	_ = runtimehooksv1.AddToCatalog(catalog)
}

// InitFlags initializes the flags.
func InitFlags(fs *pflag.FlagSet) {
	logs.AddFlags(fs, logs.SkipLoggingConfigurationFlags())
	logOptions.AddFlags(fs)

	fs.IntVar(&webhookPort, "webhook-port", 9443,
		"Webhook Server port")

	// HTTPS is required according to the Cluster API documentation.
	// cert-manager is added to the management cluster when initialized with clusterctl.
	// This cert-manager is used in this setup to generate the required secrets.
	// Existing certs can be used instead if they're available. ex: cse.ms certs.
	fs.StringVar(&webhookCertDir, "webhook-cert-dir", "/tmp/k8s-webhook-server/serving-certs/",
		"Webhook cert dir, only used when webhook-port is specified.")
}

func main() {
	InitFlags(pflag.CommandLine)
	pflag.CommandLine.SetNormalizeFunc(cliflag.WordSepNormalizeFunc)
	pflag.CommandLine.AddGoFlagSet(flag.CommandLine)
	pflag.Parse()

	if err := logOptions.ValidateAndApply(nil); err != nil {
		setupLog.Error(err, "unable to start extension")
		os.Exit(1)
	}

	// klog.Background will automatically use the right logger.
	ctrl.SetLogger(klog.Background())

	ctx := ctrl.SetupSignalHandler()

	webhookServer, err := server.NewServer(server.Options{
		Catalog: catalog,
		Port:    webhookPort,
		CertDir: webhookCertDir,
	})
	if err != nil {
		setupLog.Error(err, "error creating webhook server")
		os.Exit(1)
	}

	// Lifecycle Hooks server configuration
	// Leverage the runtime extension package from Cluster API to easily add hook handlers to the server.
	// Lifecycle hook runtime extension do not have to be written in GO, but the package provided makes it straight forward.

	// In the next few blocks below, hook endpoints are named, configured, and given handler functions.
	// The first one, for example, will correspond to the request that Cluster API will make to the endpoint,
	// /hooks.runtime.cluster.x-k8s.io/v1alpha1/beforeclustercreate/before-cluster-create
	// Other endpoints can be viewed in the swagger ui
	// https://editor.swagger.io/?url=https://cluster-api.sigs.k8s.io/tasks/experimental-features/runtime-sdk/runtime-sdk-openapi.yaml
	if err := webhookServer.AddExtensionHandler(server.ExtensionHandler{
		Hook:           runtimehooksv1.BeforeClusterCreate,
		Name:           "before-cluster-create",
		HandlerFunc:    DoBeforeClusterCreate,
		TimeoutSeconds: pointer.Int32(5),
		FailurePolicy:  toPtr(runtimehooksv1.FailurePolicyFail),
	}); err != nil {
		setupLog.Error(err, "error adding handler")
		os.Exit(1)
	}

	if err := webhookServer.AddExtensionHandler(server.ExtensionHandler{
		Hook:           runtimehooksv1.AfterControlPlaneInitialized,
		Name:           "after-control-plane-initialized",
		HandlerFunc:    DoAfterControlPlaneInitialized,
		TimeoutSeconds: pointer.Int32(5),
		FailurePolicy:  toPtr(runtimehooksv1.FailurePolicyFail),
	}); err != nil {
		setupLog.Error(err, "error adding handler")
		os.Exit(1)
	}

	if err := webhookServer.AddExtensionHandler(server.ExtensionHandler{
		Hook:           runtimehooksv1.BeforeClusterDelete,
		Name:           "before-cluster-delete",
		HandlerFunc:    DoBeforeClusterDelete,
		TimeoutSeconds: pointer.Int32(5),
		FailurePolicy:  toPtr(runtimehooksv1.FailurePolicyFail),
	}); err != nil {
		setupLog.Error(err, "error adding handler")
		os.Exit(1)
	}

	setupLog.Info("Starting Runtime Extension server")
	if err := webhookServer.Start(ctx); err != nil {
		setupLog.Error(err, "error running webhook server")
		os.Exit(1)
	}
}

// Lifecycle Hook handlers that will be referenced in the appropriate hook configuration above
func DoBeforeClusterCreate(ctx context.Context, request *runtimehooksv1.BeforeClusterCreateRequest, response *runtimehooksv1.BeforeClusterCreateResponse) {
	log := ctrl.LoggerFrom(ctx)
	log.Info("SPIKE: BeforeClusterCreate hook is called")
	// Your implementation
}

func DoAfterControlPlaneInitialized(ctx context.Context, request *runtimehooksv1.AfterControlPlaneInitializedRequest, response *runtimehooksv1.AfterControlPlaneInitializedResponse) {
	log := ctrl.LoggerFrom(ctx)
	log.Info("SPIKE: AfterControlPlaneInitialized hook is called")
	// Your implementation
}

func DoBeforeClusterDelete(ctx context.Context, request *runtimehooksv1.BeforeClusterDeleteRequest, response *runtimehooksv1.BeforeClusterDeleteResponse) {
	log := ctrl.LoggerFrom(ctx)
	log.Info("SPIKE: BeforeClusterDelete hook is called")
	// Your implementation
}

func toPtr(f runtimehooksv1.FailurePolicy) *runtimehooksv1.FailurePolicy {
	return &f
}
