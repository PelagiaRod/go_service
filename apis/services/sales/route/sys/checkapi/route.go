package checkapi

import (
	"github.com/ardanlabs/service/app/api/authclient"
	"github.com/ardanlabs/service/foundation/web"
)

func Routes(app *web.App, client *authclient.Client) {
	//authen := mid.Authorize(a)

	app.HandleFunc("GET /liveness", liveness)
	app.HandleFunc("GET /readiness", readiness)
	//app.HandleFunc("GET /testauth", liveness, authen)
}
