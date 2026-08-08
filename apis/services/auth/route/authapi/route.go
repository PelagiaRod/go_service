package authapi

import (
	"github.com/ardanlabs/service/apis/services/api/mid"
	"github.com/ardanlabs/service/business/api/auth"
	"github.com/ardanlabs/service/foundation/logger"
	"github.com/ardanlabs/service/foundation/web"
)

func Routes(app *web.App, log *logger.Logger, ath *auth.Auth) {
	authen := mid.Bearer(ath)

	api := NewAPI(ath)
	app.HandleFunc("GET /auth/token/{kid}", api.token, authen)
	app.HandleFunc("GET /auth/authenticate", api.authenticate, authen)
	app.HandleFunc("POST /auth/authorize", api.authorize)
}
