package mid

import (
	"context"
	"net/http"

	"github.com/ardanlabs/service/foundation/web"
)

func Panics() web.MidHandler {
	m := func(handler web.Handler) web.Handler {
		h := func(ctx context.Context, w http.ResponseWriter, r *http.Request) (err error) {
			defer func() {
				if r := recover(); r != nil {
					log.Error(ctx, "PANIC", "panic", r)
					web.Respond(ctx, w, web.APIError{Error: "internal server error"}, http.StatusInternalServerError)
				}
			}()

			return handler(ctx, w, r)
		}
	}
}
