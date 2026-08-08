package mux

import (
	"os"

	"github.com/ardanlabs/service/apis/services/api/mid"
	"github.com/ardanlabs/service/apis/services/auth/route/authapi"
	"github.com/ardanlabs/service/apis/services/auth/route/checkapi"
	"github.com/ardanlabs/service/business/api/auth"
	"github.com/ardanlabs/service/foundation/logger"
	"github.com/ardanlabs/service/foundation/web"
)

// WebAPI constructs a http.Handler with all application routes bound
func WebAPI(log *logger.Logger, ath *auth.Auth, shutdown chan os.Signal) *web.App {
	app := web.NewApp(shutdown, mid.Logger(log), mid.Errors(log))

	checkapi.Routes(app, log, ath)
	authapi.Routes(app, log, ath)

	return app
}
