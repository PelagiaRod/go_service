package checkapi

import (
	"github.com/ardanlabs/service/apis/services/api/mid"
	"github.com/ardanlabs/service/business/api/auth"
	"github.com/ardanlabs/service/foundation/logger"
	"github.com/ardanlabs/service/foundation/web"
)

func Routes(app *web.App, log *logger.Logger, ath *auth.Auth) {
	authen := mid.Bearer(ath)

	app.HandleFunc("GET /liveness", liveness)
	app.HandleFunc("GET /readiness", readiness)
	app.HandleFunc("GET /testauth", liveness, authen)
}
