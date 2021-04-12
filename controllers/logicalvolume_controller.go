package controllers

import (
	"context"

	"github.com/go-logr/logr"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"

	topolvmv1 "github.com/topolvm/topolvm/api/v1"
)

// LogicalVolumeReconciler reconciles a LogicalVolume object
type LogicalVolumeReconciler struct {
	client.Client
	Log    logr.Logger
	Scheme *runtime.Scheme
}

//+kubebuilder:rbac:groups=topolvm.cybozu.com,resources=logicalvolumes,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=topolvm.cybozu.com,resources=logicalvolumes/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=topolvm.cybozu.com,resources=logicalvolumes/finalizers,verbs=update

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// TODO(user): Modify the Reconcile function to compare the state specified by
// the LogicalVolume object against the actual cluster state, and then
// perform operations to make the cluster state reflect the state specified by
// the user.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.7.2/pkg/reconcile
func (r *LogicalVolumeReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	_ = r.Log.WithValues("logicalvolume", req.NamespacedName)

	// your logic here

	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *LogicalVolumeReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&topolvmv1.LogicalVolume{}).
		Complete(r)
}
