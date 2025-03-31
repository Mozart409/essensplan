use std::env;

use actix_files::NamedFile;
use actix_web::{
    get,
    http::{Method, StatusCode},
    middleware, post,
    web::{self, Data},
    App, Either, Error, HttpResponse, HttpServer, Responder,
};
use sqlx::PgPool;

mod db;

#[derive(Clone, Debug)]
pub struct AppState {
    app_name: String,
    pool: PgPool,
}

#[get("/")]
async fn index_handler(data: web::Data<AppState>) -> impl Responder {
    let app_name = &data.app_name;

    let body = format!("Hello World!!! {}", app_name);
    HttpResponse::Ok().body(body)
}

#[post("/echo")]
async fn echo(req_body: String) -> impl Responder {
    HttpResponse::Ok().body(req_body)
}

/// favicon handler
#[get("/favicon.ico")]
async fn favicon() -> Result<impl Responder, Error> {
    Ok(NamedFile::open("static/favicon.ico")?)
}

async fn default_handler(req_method: Method) -> Result<impl Responder, Error> {
    match req_method {
        Method::GET => {
            let file = NamedFile::open("static/404.html")?
                .customize()
                .with_status(StatusCode::NOT_FOUND);
            Ok(Either::Left(file))
        }
        _ => Ok(Either::Right(HttpResponse::MethodNotAllowed().finish())),
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init_from_env(env_logger::Env::new().default_filter_or("debug"));
    let database_url = env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    let pool = db::init_pool(&database_url)
        .await
        .expect("Failed to create pool");
    log::info!("starting HTTP server at http://localhost:8080");
    HttpServer::new(move || {
        App::new()
            // enable automatic response compression - usually register this first
            .wrap(middleware::Compress::default())
            .wrap(middleware::Logger::default())
            .service(index_handler)
            .service(favicon)
            .default_service(web::to(default_handler))
            .app_data(Data::new(AppState {
                app_name: "Backend".to_owned(),
                pool: pool.to_owned(),
            }))
    })
    .bind(("0.0.0.0", 8080))?
    .run()
    .await
}
