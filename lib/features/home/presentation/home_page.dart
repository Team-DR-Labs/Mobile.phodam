import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(homeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('phodam')),
      body: items.when(
        data: (list) => RefreshIndicator(
          onRefresh: ref.read(homeControllerProvider.notifier).refresh,
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = list[index];
              return ListTile(
                title: Text(item.title),
                subtitle: Text(
                  item.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('불러오지 못했어요'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: ref.read(homeControllerProvider.notifier).refresh,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
