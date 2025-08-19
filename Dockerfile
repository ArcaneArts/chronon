# Build Flutter Application
FROM --platform=linux/amd64 instrumentisto/flutter:3.32.7 AS sparrow-builder
WORKDIR /app
RUN mkdir /animal_models
COPY pubspec.* ./
COPY animal_models/pubspec.* /animal_models/
RUN flutter pub get
COPY animal_models /animal_models/
COPY . .
RUN flutter build linux --release

# Build Server Runtime
FROM --platform=linux/amd64 ubuntu:24.04
RUN apt-get update && apt-get install -y wget xvfb libgtk-3-0 libegl1 libgles2
RUN ldconfig
WORKDIR /app
COPY --from=sparrow-builder /app/build/linux/x64/release/bundle ./bundle
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib:/usr/lib:
RUN find ./bundle -type f -executable ! -name "*.so" -printf "%f\n" > executable_name.txt
EXPOSE 8080
CMD xvfb-run -a ./bundle/$(cat executable_name.txt)