/*
 * Copyright 2017 Apereo
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.tle.web.controls.universal.handlers.fileupload

import java.util.UUID

import com.tle.beans.item.attachments.Attachment
import com.tle.web.controls.universal.StagingContext

case class AttachmentCreate(createStaged: StagingContext => Attachment, commit: (Attachment, StagingContext) => Attachment, cancel: (Attachment, StagingContext) => Unit)
case class AttachmentDelete(attachments: Iterable[Attachment], deleteFiles: StagingContext => Unit)