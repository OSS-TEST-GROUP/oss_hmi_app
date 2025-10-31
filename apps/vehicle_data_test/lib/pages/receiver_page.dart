import 'package:flutter/material.dart';
import 'package:vehicle_data_test/grpc/grpc_client.dart';

class ReceiverPage extends StatefulWidget {
  const ReceiverPage({super.key, required this.cloud});
  final GrpcClient cloud;

  @override
  State<ReceiverPage> createState() => _ReceiverPageState();
}

class _ReceiverPageState extends State<ReceiverPage> with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder(
      stream: widget.cloud.events, // 클라이언트가 직접 내놓는 스트림
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Text(
              '수신 대기 중...',
              style: TextStyle(color: Colors.grey)
            ));
        }
        final dp = snapshot.data!;
        final rows = <Widget>[];
        for (final pkg in dp.data) {
          for (final p in pkg.dp) {
            rows.add(ListTile(
              title: Text(pkg.path),
              subtitle: Text(p.ts),
              trailing: Text(p.value),
            ));
          }
        }
        if (rows.isEmpty) {
          return const Center(child: Text('데이터 없음'));
        }
        return Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 20),
                child: ListView.separated(
                  //itemBuilder: (_, i) => rows[i],
                  itemBuilder: (_, i) {
                    if (i < rows.length) {
                      return rows[i];
                    }
                    return const SizedBox(height: 75);
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: rows.length + 1,
                ),
              );
      },
    );
  }
}
