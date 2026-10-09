import 'package:flutter/material.dart';
import '../network/api_exception.dart';

class NetworkFeedback extends StatelessWidget {
  const NetworkFeedback({super.key, this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(userError(error, 'Não foi possível carregar os dados.')),
          TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    ),
  );
}

class RemoteDetail<T> extends StatefulWidget {
  const RemoteDetail({super.key, required this.load, required this.builder});
  final Future<T> Function(bool retry) load;
  final Widget Function(BuildContext, T) builder;
  @override
  State<RemoteDetail<T>> createState() => _RemoteDetailState<T>();
}

class _RemoteDetailState<T> extends State<RemoteDetail<T>> {
  late Future<T> _future = widget.load(false);
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return NetworkFeedback(
          error: snapshot.error,
          onRetry: () => setState(() => _future = widget.load(true)),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return widget.builder(context, snapshot.data as T);
    },
  );
}
