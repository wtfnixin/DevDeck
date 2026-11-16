import 'package:get_it/get_it.dart';
import '../network/socket_service.dart';
import '../services/app_update_service.dart';
import '../storage/secure_storage.dart';
import '../../features/authentication/data/repositories/auth_repository_impl.dart';
import '../../features/authentication/domain/repositories/auth_repository.dart';
import '../../features/authentication/domain/usecases/check_auth_status_usecase.dart';
import '../../features/authentication/domain/usecases/logout_usecase.dart';
import '../../features/authentication/domain/usecases/pair_device_usecase.dart';
import '../../features/authentication/presentation/bloc/auth_bloc.dart';
import '../../features/connection/presentation/bloc/connection_bloc.dart';
import '../../features/launcher/presentation/bloc/launcher_bloc.dart';
import '../../features/clipboard/presentation/bloc/clipboard_bloc.dart';
import '../../features/workspace/presentation/bloc/workspace_bloc.dart';
import '../../features/gestures/presentation/bloc/gesture_bloc.dart';

final sl = GetIt.instance;

Future<void> initInjection() async {
  // 1. Storage & Services (Async Initializers)
  final secureStorage = await SecureStorage.init();
  sl.registerSingleton<SecureStorage>(secureStorage);
  sl.registerLazySingleton<AppUpdateService>(() => AppUpdateService(secureStorage: sl<SecureStorage>()));

  // 2. Core Network
  sl.registerLazySingleton<SocketService>(() => SocketService(sl<SecureStorage>()));

  // 3. Features - Authentication
  // Repositories
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(
        sl<SecureStorage>(),
        sl<SocketService>(),
      ));

  // Use Cases
  sl.registerLazySingleton(() => CheckAuthStatusUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => PairDeviceUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => LogoutUseCase(sl<AuthRepository>()));

  // BLoCs
  sl.registerFactory(() => AuthBloc(
        checkAuthStatus: sl<CheckAuthStatusUseCase>(),
        pairDevice: sl<PairDeviceUseCase>(),
        logout: sl<LogoutUseCase>(),
        secureStorage: sl<SecureStorage>(),
      ));

  sl.registerFactory(() => ConnectionBloc(sl<SocketService>()));
  sl.registerFactory(() => LauncherBloc(sl<SocketService>()));
  sl.registerFactory(() => ClipboardBloc(sl<SocketService>(), sl<SecureStorage>()));
  sl.registerFactory(() => WorkspaceBloc(sl<SocketService>()));
  sl.registerFactory(() => GestureBloc(sl<SocketService>()));
}
