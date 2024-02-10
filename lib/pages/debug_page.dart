// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2023, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:json_view/json_view.dart';
import 'package:provider/provider.dart';

import '../models/api_model.dart';
import '../models/conversations.dart';

class DebugPage extends StatelessWidget {
  const DebugPage();

  @override
  Widget build(BuildContext context) {
    var curConv = Provider.of<ConversationsModel>(context).current;
    var apiModel = Provider.of<ApiModel>(context);
    var request = apiModel.rawRequest;
    var response = apiModel.rawResponse;

    return Scaffold(
      appBar: AppBar(
        title: Text(curConv?.name ?? '')
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Request', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              if(request != null)
                JsonView(
                  json: request,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics()
                )
              else
                const Text('N/A'),
              Row(
                children: [
                  Text(
                    'Response (${(apiModel.requestMsecs / 1000).toStringAsFixed(1)}s)',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
              if(response != null)
                JsonView(
                  json: response,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics()
                )
              else
                const Text('N/A'),
            ]
          )
        )
      )
    );
  }
}
