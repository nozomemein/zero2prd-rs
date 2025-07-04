use std::net::TcpListener;

use actix_web::{App, HttpServer, dev::Server, web};

use crate::routes::{health_check, subscribe};

pub mod configuration;
pub mod routes;
pub mod startup;

pub fn run(listener: TcpListener) -> Result<Server, std::io::Error> {
    let server = HttpServer::new(|| {
        App::new()
            .route("/health_check", web::get().to(health_check))
            .route("/subscriptions", web::post().to(subscribe))
    })
    .listen(listener)?
    .run();

    Ok(server)
}
