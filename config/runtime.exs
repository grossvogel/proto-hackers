import Config

config :proto_hackers, port: String.to_integer(System.get_env("PORT", "4000"))
